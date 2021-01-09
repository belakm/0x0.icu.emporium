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
  author_id        INTEGER NOT NULL REFERENCES forum_example.person(id),
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

CREATE ROLE forum_example_postgraphile login password 'xyz';

CREATE TYPE 0x0.jwt_token as (
  role TEXT,
  person_id INTEGER,
  exp BIGINT
);

CREATE FUNCTION 0x0.authenticate(
  email text,
  password text
) returns 0x0.jwt_token as $$
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

comment on function 0x0.authenticate(text, text) is 'Creates a JWT token that will securely identify a person and give them certain permissions. This token expires in 1 day.';