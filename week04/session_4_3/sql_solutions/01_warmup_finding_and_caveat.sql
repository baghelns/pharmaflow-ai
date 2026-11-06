-- Warm-Up: one number, two findings. Toy data: complaints about the hostel
-- mess, four weeks. Week 3 holds six complaints about poha from one student,
-- sent in one go.
CREATE OR REPLACE TABLE complaints AS
SELECT * FROM (VALUES
  (1, 'dal',   'Ravi'), (1, 'poha', 'Meera'), (1, 'rice',  'Asha'),
  (2, 'dal',   'Kiran'), (2, 'dal', 'Meera'), (2, 'rice', 'Ravi'),
  (3, 'poha',  'Arjun'), (3, 'poha', 'Arjun'), (3, 'poha', 'Arjun'),
  (3, 'poha',  'Arjun'), (3, 'poha', 'Arjun'), (3, 'poha', 'Arjun'),
  (3, 'dal',   'Asha'),
  (4, 'dal',   'Kiran'), (4, 'rice', 'Meera'), (4, 'poha', 'Asha')
) AS t(week, dish, student);

-- 1. The headline: complaints per dish
SELECT dish, COUNT(*) AS complaints
FROM complaints
GROUP BY dish
ORDER BY complaints DESC, dish;

-- 2. The caveat: how many people complained, and the count without
--    one student's batch of six
SELECT dish,
       COUNT(*) AS complaints,
       COUNT(DISTINCT student) AS students,
       COUNT(*) FILTER (WHERE NOT (week = 3 AND student = 'Arjun'))
           AS without_the_batch
FROM complaints
GROUP BY dish
ORDER BY complaints DESC, dish;
