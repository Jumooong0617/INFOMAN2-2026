CREATE TABLE authors (
  id SERIAL NOT NULL PRIMARY KEY,
  first_name varchar(50) NOT NULL,
  last_name varchar(50) NOT NULL,
  email varchar(100) UNIQUE NOT NULL,
  birthdate date NOT NULL,
  added timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE posts (
  id SERIAL NOT NULL PRIMARY KEY,
  author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
  title varchar(255) NOT NULL,
  description varchar(500) NOT NULL,
  content text NOT NULL,
  date date NOT NULL
);

