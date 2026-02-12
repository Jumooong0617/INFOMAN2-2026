-- SCENARIO 1
CREATE INDEX idx_auhor_id on posts(author_id);
CREATE INDEX idx_date on posts (date);

-- SCENARIO 2
CREATE INDEX idx_posts_title ON posts(title);

--SCENARIO 3