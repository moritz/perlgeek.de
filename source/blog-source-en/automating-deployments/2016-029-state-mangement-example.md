Continuous Schema Changes: An Example
<!-- 2016-08-18 -->

<p>Suppose you have a web application backed by a PostgreSQL database, and
currently the application logs login attempts into the database. So the schema
looks like this:</p>

<pre><code>CREATE TABLE users (
    id          SERIAL,
    email       VARCHAR NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE login_attempts (
    id          SERIAL,
    user_id     INTEGER NOT NULL REFERENCES users (id),
    success     BOOLEAN NOT NULL,
    timestamp   TIMESTAMP NOT NULL DEFAULT NOW(),
    source_ip   VARCHAR NOT NULL,
    PRIMARY KEY(id)
);
</code></pre>

<p>As the load on the web application increases, you realize that you are
creating unnecessary write load for the database, and start logging to an
external log
service. The only thing you really need in the database is the date and time
of the last successful login (which your CEO insists you show on each
login, because an auditor was convinced it would improve security).</p>

<p>So the schema you want to end up with is this:</p>

<pre><code>CREATE TABLE users (
    id          SERIAL,
    email       VARCHAR NOT NULL,
    last_login  TIMESTAMP NOT NULL,
    PRIMARY KEY(id)
);
</code></pre>

<p>If you generated or wrote a migration script that produced this schema, and
updated the application to deal with the new schema, all in a single step,
you'd have to stop the application, migrate the database (which might take
hours if your tables are very large), and then install the new version of the
application.</p>

<p>Hating downtimes is a good reason not to do the migration in one step,
especially if you consider what happens when the release fails. To be able to
roll back to a previous application version, you also have to roll back the
schema version, which again comes with a long downtime.</p>

<p>In addition, downtimes typically need to be scheduled outside the normal
business hours, so they require extra effort, and put the application into
a state where it cannot be released to production for a time, which goes
against the idea of Continuous Delivery.</p>

<h2>Breaking it Down in Smaller Pieces</h2>

<p>Instead of a single big all-or-nothing migration, let's strive for several
smaller steps.</p>

<h3>Creating the New Column, NULLable</h3>

<p>The first step is to add the new column, <code>users.last_login</code>, as optional (so
allowing <code>NULL</code> values). If the starting point was version 1 of the schema,
this is version 2:</p>

<pre><code>CREATE TABLE users (
    id          SERIAL,
    email       VARCHAR NOT NULL,
    last_login  TIMESTAMP,
    PRIMARY KEY(id)
);

-- table login_attempts omitted, because it's unchanged.
</code></pre>

<p>Running <code>apgdiff schma-1.sql schema-2.sql</code> gives us</p>

<pre><code>ALTER TABLE users
    ADD COLUMN last_login TIMESTAMP;
</code></pre>

<p>which is the forward migration script from schema 1 to schema 2. Note that we
don't necessarily need a rollback script, because every application version
that can deal with version 1 of the schema can also deal with schema version
2. (Unless the application does something stupid like <code>SELECT * FROM users</code>
and expecting a certain number or order of results. I'll assume the
application isn't that stupid).</p>

<p>This migration script can be applied to the database while the web application
is running, without any downtime.</p>

<p>When it's finished, you can deploy a new version of the web
application that writes to <code>users.last_login</code> when a successful login occurs.
Note that this application version must be able to deal with reading <code>NULL</code>
values from this column (for example by falling back to table <code>login_attempts</code>
to determine the last login attempt).</p>

<p>This application version can also stop inserting new entries into table
<code>login_attempts</code>. A more conservative approach is to defer that step for a
while, so that you can safely roll back to an older application version.</p>

<h3>Data Migration</h3>

<p>In the end, <code>users.last_login</code> is meant to be <code>NOT NULL</code>, so you have to
generate values for where it's <code>NULL</code>. Here table <code>last_login</code> is a source
for such data:</p>

<pre><code>UPDATE users
  SET last_login = (
         SELECT login_attempts.timestamp
           FROM login_attempts
          WHERE login_attempts.user_id = users.id
            AND login_attempts.success
       ORDER BY login_attempts.timestamp DESC
          LIMIT 1
       )
 WHERE users.last_login IS NULL;
</code></pre>

<p>If <code>NULL</code>-values remain, for example because a user never logged in
successfully, or because table <code>last_login</code> doesn't go back long enough, you
need to have some fallback, which could be a fixed value. Here I'm taking the
easy road and simply use <code>NOW()</code> as the fallback:</p>

<pre><code>UPDATE users SET last_login = NOW() WHERE last_login IS NULL;
</code></pre>

<p>These two updates can again run in the background, while the application is
running.</p>

<p>After this update, no more <code>NULL</code> values should show up in <code>users.last_login</code>.
After waiting a few days, and verifying that this is indeed the case, it's
time to apply the necessary constraint.</p>

<h3>Applying Constraints, Cleaning Up</h3>

<p>Once you are confident that there are no rows that miss values in the
column <code>last_login</code>, and that you aren't going to roll back to an application
version that introduces missing values, you can apply the necessary
constraints, and dispose of the <code>login_attempts</code> table:</p>

<pre><code>DROP TABLE login_attempts;

ALTER TABLE users
    ALTER COLUMN last_login SET NOT NULL;
</code></pre>

<h2>Summary</h2>

<p>In order to avoid both downtimes and risky updates, database schema changes
can be broken up into smaller pieces that can be applied during normal
operations, so without a downtime.</p>

<p>These schema changes need to be interleaved with application releases that
support the schema changes.</p>

<p>Having several steps instead of means you need an automated process (or at
least semi automated process) to deal with the many releases and schema
changes.</p>

[% include ad-mailing %]

[% option no-header %][% option no-footer %]
[% comment vim: set ft=html: %]
