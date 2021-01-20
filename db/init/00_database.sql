\connect 0x0_db;

--
--
-- DB SETUP
--
--

CREATE SCHEMA 0x0;
CREATE SCHEMA 0x0_private;

CREATE TABLE 0x0.person (
  id              SERIAL PRIMARY KEY,
  first_name      TEXT NOT NULL CHECK (char_length(first_name) < 80),
  last_name       TEXT CHECK (char_length(last_name) < 80),
  about           TEXT,
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW()
)

COMMENT ON TABLE 0x0.person is 'A user of the service.';
COMMENT ON COLUMN 0x0.person.id is 'The primary unique identifier for the person.';
COMMENT ON COLUMN 0x0.person.first_name is 'The person’s first name.';
COMMENT ON COLUMN 0x0.person.last_name is 'The person’s last name.';
COMMENT ON COLUMN 0x0.person.about is 'A short description about the user, written by the user.';
COMMENT ON COLUMN 0x0.person.created_at is 'The time this person was created.';

CREATE TYPE 0x0.post_topic AS ENUM(
  'shitpost',
  'good shit',
  'oc'
);

CREATE TABLE 0x0.post (
  id               SERIAL PRIMARY KEY,
  author_id        INTEGER NOT NULL REFERENCES 0x0.person(id),
  headline         TEXT NOT NULL CHECK (char_length(headline) < 280),
  body             TEXT,
  topic            0x0.post_topic,
  created_at       TIMESTAMP DEFAULT NOW(),
  updated_at       TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE 0x0.post is 'A forum post written by a user.';
COMMENT ON COLUMN 0x0.post.id is 'The primary key for the post.';
COMMENT ON COLUMN 0x0.post.headline is 'The title written by the user.';
COMMENT ON COLUMN 0x0.post.author_id is 'The id of the author user.';
COMMENT ON COLUMN 0x0.post.topic is 'The topic this has been posted in.';
COMMENT ON COLUMN 0x0.post.body is 'The main body text of our post.';
COMMENT ON COLUMN 0x0.post.created_at is 'The time this post was created.';

-- By default, functions can be executable by public. Since we're applying our fine-grained control over function permissions here, we remove the default grant. Note that this line needs to be placed before any function definition.
alter default privileges revoke execute on functions from public;

CREATE FUNCTION 0x0.person_full_name(person 0x0.person) returns text as $$
  select person.first_name || ' ' || person.last_name
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION 0x0.person_full_name(0x0.person) is 'A person’s full name which is a concatenation of their first and last name.';

CREATE FUNCTION 0x0.post_summary(
  post 0x0.post,
  length int default 50,
  omission text default '…'
) returns text as $$
  select case
    when post.body is null then null
    else substr(post.body, 0, length) || omission
  end
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION 0x0.post_summary(0x0.post, int, text) is 'A truncated version of the body for summaries.';

CREATE FUNCTION 0x0.person_latest_post(person 0x0.person) returns 0x0.post as $$
  SELECT post.*
  FROM 0x0.post AS post
  WHERE post.author_id = person.id
  ORDER BY created_at DESC
  LIMIT 1
$$ language sql stable;

COMMENT ON FUNCTION 0x0.person_latest_post(0x0.person) is 'Get’s the latest post written by the person.';

create function 0x0.search_posts(search text) returns setof 0x0.post as $$
  select post.*
  from 0x0.post as post
  where position(search in post.headline) > 0 or position(search in post.body) > 0
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION 0x0.search_posts(text) is 'Returns posts containing a given search term.';

CREATE FUNCTION 0x0_private.set_updated_at() returns trigger as $$
begin
  new.updated_at := current_timestamp;
  return new;
end;
$$ LANGUAGE plpgsql;

CREATE TRIGGER person_updated_at BEFORE UPDATE
  on 0x0.person
  for each row
  execute procedure 0x0_private.set_updated_at();

CREATE TRIGGER post_updated_at BEFORE UPDATE
  on 0x0.post
  for each row
  execute procedure 0x0_private.set_updated_at();

CREATE TABLE 0x0_private.person_account (
  person_id        INTEGER PRIMARY KEY REFERENCES 0x0.person(id) ON DELETE CASCADE,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL
);

COMMENT ON TABLE 0x0_private.person_account is 'Private information about a person’s account.';
COMMENT ON COLUMN 0x0_private.person_account.person_id is 'The id of the person associated with this account.';
COMMENT ON COLUMN 0x0_private.person_account.email is 'The email address of the person.';
COMMENT ON COLUMN 0x0_private.person_account.password_hash is 'An opaque hash of the person’s password.';

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE FUNCTION 0x0.register_person(
  first_name text,
  last_name text,
  email text,
  password text
) returns 0x0.person as $$
declare
  person 0x0.person;
begin
  insert into 0x0.person (first_name, last_name) values
    (first_name, last_name)
    returning * into person;

  insert into 0x0_private.person_account (person_id, email, password_hash) values
    (person.id, email, crypt(password, gen_salt('bf')));

  return person;
end;
$$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

COMMENT ON FUNCTION 0x0.register_person(text, text, text, text) IS 'Registers a single user and creates an account in our service.';

--
--
-- AUTHENTICATION WITH JWT
--
--

-- create superadmin role
CREATE ROLE 0x0_postgraphile login password 'change_me';

-- create anon role
CREATE ROLE 0x0_anonymous;
GRANT 0x0_anonymous TO 0x0_postgraphile;

-- create user role
CREATE ROLE 0x0_person;
GRANT 0x0_person TO 0x0_postgraphile;

CREATE TYPE 0x0.jwt_token as (
  role TEXT,
  person_id INTEGER,
  exp BIGINT
);

CREATE FUNCTION 0x0.authenticate(
  email text,
  password text
) RETURNS 0x0.jwt_token AS $$
declare
  account 0x0_private.person_account;
begin
  select a.* into account
  from 0x0_private.person_account as a
  where a.email = $1;

  if account.password_hash = crypt(password, account.password_hash) then
    return ('0x0_person', account.person_id, extract(epoch from (now() + interval '1 day')))::0x0.jwt_token;
  else
    return null;
  end if;
end;
$$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

COMMENT ON FUNCTION 0x0.authenticate(text, text) IS 'Creates a JWT token that will securely identify a person and give them certain permissions. This token expires in 1 day.';

CREATE FUNCTION 0x0.current_person() RETURNS 0x0.person AS $$
  select *
  from 0x0.person
  where id = nullif(current_setting('jwt.claims.person_id', true), '')::integer
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION 0x0.current_person() IS 'Gets the person who was identified by our JWT.';

-- grant knowledge of 0x0 schema to anons and logged in users
grant usage on schema 0x0 to 0x0_anonymous, 0x0_person;

-- grant anons and logged in users 0x0.person sellected privileges on 0x0.person
grant select on table 0x0.person to 0x0_anonymous, 0x0_person;
grant update, delete on table 0x0.person to 0x0_person;

-- grant anons and logged in users 0x0.person sellected privileges on 0x0.post
grant select on table 0x0.post to 0x0_anonymous, 0x0_person;
grant insert, update, delete on table 0x0.post to 0x0_person;
--  When a user creates a new 0x0.post they will also need to get the next value in the 0x0.post_id_seq because we use the serial data type for the id column
grant usage on sequence 0x0.post_id_seq to 0x0_person;

-- grant anons and logged in users access to all functions
grant execute on function 0x0.person_full_name(0x0.person) to 0x0_anonymous, 0x0_person;
grant execute on function 0x0.post_summary(0x0.post, integer, text) to 0x0_anonymous, 0x0_person;
grant execute on function 0x0.person_latest_post(0x0.person) to 0x0_anonymous, 0x0_person;
grant execute on function 0x0.search_posts(text) to 0x0_anonymous, 0x0_person;
grant execute on function 0x0.authenticate(text, text) to 0x0_anonymous, 0x0_person;
grant execute on function 0x0.current_person() to 0x0_anonymous, 0x0_person;

-- except for registration which is only granted to anons
grant execute on function 0x0.register_person(text, text, text, text) to 0x0_anonymous;

-- ROW LEVEL SECURITY
alter table 0x0.person enable row level security;
alter table 0x0.post enable row level security;

-- anons and logged in can see all posts and persons
create policy select_person on 0x0.person for select
  using (true);

create policy select_post on 0x0.post for select
  using (true);

-- only logged in users can delete and update their own person data
create policy update_person on 0x0.person for update to 0x0_person
  using (id = nullif(current_setting('jwt.claims.person_id', true), '')::integer);

create policy delete_person on 0x0.person for delete to 0x0_person
  using (id = nullif(current_setting('jwt.claims.person_id', true), '')::integer);

-- only logged in users can update and delete their own posts
create policy insert_post on 0x0.post for insert to 0x0_person
  with check (author_id = nullif(current_setting('jwt.claims.person_id', true), '')::integer);

create policy update_post on 0x0.post for update to 0x0_person
  using (author_id = nullif(current_setting('jwt.claims.person_id', true), '')::integer);

create policy delete_post on 0x0.post for delete to 0x0_person
  using (author_id = nullif(current_setting('jwt.claims.person_id', true), '')::integer);