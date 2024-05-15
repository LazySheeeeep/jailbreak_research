DROP DATABASE IF EXISTS jailbreak_research;
CREATE DATABASE jailbreak_research;

USE jailbreak_research;

DROP TABLE IF EXISTS models;
CREATE TABLE models (
    model_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    gguf_name VARCHAR(100) UNIQUE,
    api_url VARCHAR(100)
);

DROP TABLE IF EXISTS proprietors;
CREATE TABLE proprietors(
    ppt_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(20) UNIQUE NOT NULL
);

DROP TABLE IF EXISTS judges;
CREATE TABLE judges (
    name VARCHAR(20) PRIMARY KEY,
    api_url VARCHAR(100),
    ppt_id int,
    FOREIGN KEY (ppt_id) REFERENCES proprietors(ppt_id) ON DELETE SET NULL
);

DROP TABLE IF EXISTS api_keys;
CREATE TABLE api_keys (
    ak VARCHAR(100) UNIQUE NOT NULL,
    ak_id int PRIMARY KEY AUTO_INCREMENT,
    ppt_id int NOT NULL,
    available boolean DEFAULT TRUE,
    FOREIGN KEY (ppt_id) REFERENCES proprietors(ppt_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS prohibited_scenarios;
CREATE TABLE prohibited_scenarios (
    ps_id INT PRIMARY KEY AUTO_INCREMENT,
    ps VARCHAR(25) NOT NULL UNIQUE
);

DROP TABLE IF EXISTS malicious_questions;
CREATE TABLE malicious_questions (
    ps_id INT NOT NULL,
    mq_id INT NOT NULL,
    mq VARCHAR(500) NOT NULL UNIQUE,
    FOREIGN KEY (ps_id) REFERENCES prohibited_scenarios(ps_id) ON DELETE CASCADE,
    PRIMARY KEY (ps_id, mq_id)
);

DROP TABLE IF EXISTS jailbreak_tactics;
CREATE TABLE jailbreak_tactics (
    jt_id INT PRIMARY KEY AUTO_INCREMENT,
    jt VARCHAR(25) UNIQUE
);

DROP TABLE IF EXISTS jailbreak_prompts;
CREATE TABLE jailbreak_prompts (
    jt_id INT NOT NULL,
    jp_id INT NOT NULL,
    jp TEXT,
    FOREIGN KEY (jt_id) REFERENCES jailbreak_tactics(jt_id) ON DELETE CASCADE,
    PRIMARY KEY (jt_id, jp_id)
);

DROP TABLE IF EXISTS responses;
CREATE TABLE responses (
    response_id INT PRIMARY KEY AUTO_INCREMENT,
    model_id INT NOT NULL,
    jt_id INT NOT NULL,
    jp_id INT NOT NULL,
    ps_id INT NOT NULL,
    mq_id INT NOT NULL,
    repeat_times INT NOT NULL,
    response TEXT NOT NULL,
    UNIQUE (model_id, jt_id, jp_id, ps_id, mq_id, repeat_times),
    FOREIGN KEY (model_id) REFERENCES models(model_id) ON DELETE CASCADE,
    FOREIGN KEY (jt_id, jp_id) REFERENCES jailbreak_prompts(jt_id, jp_id) ON DELETE CASCADE,
    FOREIGN KEY (ps_id, mq_id) REFERENCES malicious_questions(ps_id, mq_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS rating_prompt_templates;
CREATE TABLE rating_prompt_templates (
    rpt_id INT PRIMARY KEY AUTO_INCREMENT,
    rpt_s TEXT NOT NULL, -- rating template system prompt part
    rpt_u TEXT NOT NULL  -- rating template user prompt part
);

DROP TABLE IF EXISTS scores;
CREATE TABLE scores (
    judge VARCHAR(20) NOT NULL,
    rpt_id INT NOT NULL,
    response_id INT NOT NULL,
    score INT,
    PRIMARY KEY (judge, rpt_id, response_id),
    FOREIGN KEY (judge) REFERENCES judges(name) ON DELETE CASCADE,
    FOREIGN KEY (rpt_id) REFERENCES rating_prompt_templates(rpt_id) ON DELETE CASCADE,
    FOREIGN KEY (response_id) REFERENCES responses(response_id) ON DELETE CASCADE
);

DROP VIEW IF EXISTS scoress;
CREATE VIEW scoress AS SELECT
model_id, ps_id, mq_id, jt_id, jp_id, repeat_times, response_id, judge, rpt_id, score
FROM responses
JOIN scores USING(response_id);

DROP VIEW IF EXISTS api_keyss;
CREATE VIEW api_keyss AS SELECT
name, ak, available
FROM api_keys
JOIN judges USING(ppt_id);

DELIMITER $$
CREATE TRIGGER check_content_before_insert
BEFORE INSERT ON rating_prompt_templates
FOR EACH ROW
BEGIN
    IF NOT (NEW.rpt_s LIKE '%OBJECTIVE%') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rpt_s must contain the word OBJECTIVE';
    END IF;
    IF NOT (NEW.rpt_u LIKE '%RESPONSE%') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rpt_u must contain the word RESPONSE';
    END IF;
END$$
DELIMITER ;

