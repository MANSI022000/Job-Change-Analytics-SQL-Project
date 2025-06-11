CREATE DATABASE db_JobChangeAnalytics;
USE db_JobChangeAnalytics;

SELECT * FROM aug_train;

--RETENTION &  ATTRITION INSIGHTS
--1. Percentage of candidates actively looking for a new job
SELECT ROUND(100 * SUM(CASE WHEN target = 1 THEN 1 ELSE 0 END)/COUNT(*),2) AS Target_Candidated 
FROM aug_train; -- Assuming 1:actively looking ; 0:not actively looking

--2. City having highest Attrition Rate
SELECT TOP 1 City, COUNT(city) AS HighestAttritionCity FROM aug_train
WHERE Target = 1
GROUP BY city
ORDER BY HighestAttritionCity DESC;

--3. Correlation between experience and job change behavior
SELECT (AVG(CAST(numeric_experience * target AS FLOAT)) - AVG(numeric_experience) * AVG(target))/
        (STDEV(numeric_experience)*STDEV(target)) AS Correlation
FROM (SELECT target,
  CASE
    WHEN experience = '<1' THEN 0.5
    WHEN experience = '>20' THEN 21
    WHEN ISNUMERIC(experience) = 1 THEN CAST(experience AS DECIMAL(4,2))
    ELSE NULL
  END AS numeric_experience
FROM aug_train) AS Cleansed_Data 
WHERE numeric_experience IS NOT NULL;

--4. Company type having the highest employee churn
SELECT company_type,(100* SUM(CASE WHEN target = 1 THEN 1 ELSE 0 END)/COUNT(*)) AS Churn_Rate
FROM aug_train
GROUP BY company_type;

--5. Do people with more training hours tend to switch jobs more?
SELECT ROUND((AVG(training_hours * target) - (AVG(training_hours)*AVG(target)))/
        (STDEV(training_hours)*STDEV(target)),2) AS Correlation
FROM aug_train;

--EDUCATION AND UPSKILLING TRENDS
--1. Education level having the highest job switching tendencies
SELECT TOP 1 education_level, COUNT(CASE WHEN target = 1 THEN 1 ELSE 0 END) AS No_of_employees
FROM aug_train
GROUP BY education_level
ORDER by No_of_employees DESC;

--2. What’s the average training hours per education level and major discipline?
SELECT education_level, major_discipline, AVG(training_hours) AS Avg_training_hours
FROM aug_train
GROUP BY education_level, major_discipline
ORDER BY education_level, major_discipline;

--3. Does being enrolled in university affect job-switching intent?
SELECT enrolled_university, COUNT(target) AS job_switch_intent FROM aug_train
WHERE target = 1
GROUP BY enrolled_university
ORDER by job_switch_intent DESC;

--COMPANY INSIGHTS
--1. Which company type has the most experienced employees (>10 years)
SELECT company_type, COUNT(numeric_experience) AS No_of_experienced_employees
FROM (SELECT company_type,
        CASE
            WHEN experience = '<1' THEN 0.5
            WHEN experience = '>20' THEN 21
            WHEN ISNUMERIC(experience) = 1 THEN CAST(experience AS DECIMAL(4,2))
            ELSE NULL
        END AS numeric_experience
FROM aug_train) AS Cleansed_Data 
WHERE numeric_experience > 10
GROUP BY company_type
ORDER BY No_of_experienced_employees DESC;

--2. Is there a company type preferred by people with less than 2 years of experience?
SELECT company_type, COUNT(numeric_experience) AS No_of_experienced_employees
FROM (SELECT company_type,
        CASE
            WHEN experience = '<1' THEN 0.5
            WHEN experience = '>20' THEN 21
            WHEN ISNUMERIC(experience) = 1 THEN CAST(experience AS DECIMAL(4,2))
            ELSE NULL
        END AS numeric_experience
FROM aug_train) AS Cleansed_Data 
WHERE numeric_experience < 2
GROUP BY company_type
ORDER BY No_of_experienced_employees DESC;

--3. Distribution of people who’ve never had a new job (last_new_job = never)
SELECT (100*
            (SELECT COUNT(*) FROM aug_train WHERE last_new_job = 'never' OR last_new_job IS NULL)/
            (SELECT COUNT(*) FROM aug_train)) AS never_has_job;

-- CITY & GEOGRAPHY BASED ANALYSIS
--1. Cities having the most highly developed index but still high job-switching intent?
SELECT TOP 5 city, 
       AVG(city_development_index) AS avg_development_index,
       COUNT(*) AS switchers
FROM aug_train
WHERE target = 1
GROUP BY city
HAVING AVG(city_development_index) > (
    SELECT AVG(city_development_index) FROM aug_train
)
ORDER BY avg_development_index DESC;

--2. How does city_development_index correlate with target = 1 (job switch intent)?
SELECT ROUND((AVG(city_development_index * target) - (AVG(city_development_index) * AVG(target))) / 
    (STDEV(city_development_index) * STDEV(target)),2) AS correlation
FROM aug_train;

--3. Top 5 cities with highest concentration of STEM majors seeking new jobs.
SELECT TOP 5 city, COUNT(*) AS Having_stem_major
FROM aug_train
WHERE target = 1 AND major_discipline = 'STEM'
GROUP BY city
ORDER BY Having_stem_major DESC;

--EXPERIENCE vs TARGET PREDICTION
--1. AVG training hours for each experience bracket
SELECT experience, AVG(training_hours) AS training_hours
FROM aug_train
WHERE experience IS NOT NULL
GROUP BY experience
ORDER BY 
    CASE   
       WHEN experience = '<1' THEN 0
       WHEN experience = '>20' THEN 21
       ELSE CAST(experience AS INT)
     END;

--2. Among candidates with "<1" experience, what percentage are looking to switch?
SELECT (100 * COUNT(CASE WHEN experience = '<1' AND target = 1 THEN 1 END) / 
        COUNT(CASE WHEN experience = '<1' THEN 1 END)) AS 'Percentage'
FROM aug_train;

--3. Which experience levels are most likely to look for a job change?
SELECT TOP 5 experience, COUNT(target) AS Want_to_Switch
FROM aug_train
WHERE target = 1
GROUP BY experience
ORDER BY Want_to_Switch DESC;

--GENDER & DIVERSITY ANALYSIS
--1. Gender distribution across education level
SELECT education_level, gender, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY education_level), 2) AS percentage
FROM aug_train
WHERE education_level IS NOT NULL AND gender IS NOT NULL
GROUP BY education_level, gender
ORDER BY education_level, gender;

--2. Do men or women have higher training hours on average?
SELECT gender, AVG(training_hours) AS AvgTraniningHours
FROM aug_train
GROUP BY gender
ORDER BY AvgTraniningHours DESC;

--3. Does gender play a role in job-switching behavior?
SELECT gender, (100* (SUM(CASE WHEN target = 1 THEN 1 ELSE 0 END))/(COUNT(*))) AS SwitcerPer
FROM aug_train
WHERE gender IS NOT NULL 
GROUP BY gender
ORDER BY SwitcerPer;

--ENRICHMENT & SEGMENT PROFILING
--1. Create a candidate segmentation by experience, city_index & training_hours to 
--see switch intent per segment.
SELECT experience,
                    (CASE
                        WHEN city_development_index < 0.5 THEN 'Low'
                        WHEN city_development_index BETWEEN 0.5 AND 0.75 THEN 'Medium'
                        ELSE 'High'
                    END) AS DevIndexBucket,
                    (CASE 
                        WHEN training_hours < 25 THEN 'Low'
                        WHEN training_hours BETWEEN 25 AND 75 THEN 'Medium'
                        ELSE 'High'
                    END) AS TrainingBucket,
                    COUNT(*) AS Total_Candidates,
                    (100.0 * (SUM(CASE WHEN target = 1 THEN 1 ELSE 0 END))/CAST(COUNT(*) AS DECIMAL(6,1))) AS SwitchersPer
FROM aug_train
WHERE experience IS NOT NULL AND city_development_index IS NOT NULL AND training_hours IS NOT NULL
GROUP BY experience, 
                    (CASE
                        WHEN city_development_index < 0.5 THEN 'Low'
                        WHEN city_development_index BETWEEN 0.5 AND 0.75 THEN 'Medium'
                        ELSE 'High'
                    END),
                    (CASE 
                        WHEN training_hours < 25 THEN 'Low'
                        WHEN training_hours BETWEEN 25 AND 75 THEN 'Medium'
                        ELSE 'High'
                    END)
ORDER BY SwitchersPer DESC;

--2. Which combinations (e.g., Female + Graduate + STEM + Pvt Ltd) have the highest switch rate?
SELECT gender, education_level, major_discipline,company_type, 
       ROUND((100.0 * SUM(CASE WHEN target = 1 THEN 1 ELSE 0 END)/COUNT(*)),2) AS SwitchRate
FROM aug_train
WHERE gender IS NOT NULL AND education_level IS NOT NULL AND major_discipline IS NOT NULL AND 
company_type IS NOT NULL AND target IS NOT NULL
GROUP BY gender, education_level, major_discipline,company_type
ORDER BY SwitchRate DESC;

--3. Which group of employees is the most stable (lowest switch intent)?
SELECT gender, education_level, major_discipline,company_type, 
       ROUND((100.0 * SUM(CASE WHEN target = 1 THEN 1 ELSE 0 END)/COUNT(*)),2) AS SwitchRate
FROM aug_train
WHERE gender IS NOT NULL AND education_level IS NOT NULL AND major_discipline IS NOT NULL AND 
company_type IS NOT NULL AND target IS NOT NULL
GROUP BY gender, education_level, major_discipline,company_type
ORDER BY SwitchRate;