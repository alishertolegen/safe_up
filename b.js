const express = require("express");
const { Pool } = require("pg");
const bcrypt = require("bcrypt");
const cors = require("cors");
const jwt = require("jsonwebtoken");

require('dotenv').config();
const axios = require('axios');

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

const pool = new Pool({
  user: "postgres.knfwvqzkebmwcfsveclj",
  host: "aws-1-ap-northeast-2.pooler.supabase.com",
  database: "postgres",
  password: "Tolegen1337@",
  port: 6543,
});

const JWT_SECRET = "super_secret_key";

function authMiddleware(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) return res.sendStatus(401);

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}

app.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;

    const checkUser = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
    if (checkUser.rows.length > 0) {
      return res.status(400).json({ error: "Пользователь уже существует" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await pool.query(
      "INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email",
      [name, email, hashedPassword]
    );

    const token = jwt.sign(
      { id: result.rows[0].id, email: result.rows[0].email },
      JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.json({ user: result.rows[0], token });
  } catch (err) {
    console.error("Register error:", err);
    res.status(500).json({ error: "Ошибка регистрации" });
  }
});

app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
    if (result.rows.length === 0) {
      return res.status(400).json({ error: "Неверный email или пароль" });
    }

    const user = result.rows[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(400).json({ error: "Неверный email или пароль" });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.json({ user: { id: user.id, name: user.name, email: user.email }, token });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: "Ошибка входа" });
  }
});

app.get("/users", async (req, res) => {
  try {
    const result = await pool.query("SELECT id, name, email, created_at FROM users");
    res.json(result.rows);
  } catch (err) {
    console.error("Get users error:", err);
    res.status(500).json({ error: "Ошибка получения пользователей" });
  }
});

app.get("/profile", authMiddleware, async (req, res) => {
  try {
    const user = await pool.query("SELECT id, name, email FROM users WHERE id = $1", [req.user.id]);
    res.json(user.rows[0]);
  } catch (err) {
    console.error("Profile error:", err);
    res.status(500).json({ error: "Ошибка получения профиля" });
  }
});
// хелпер ии api
async function callRouter(body) {
  const HF_TOKEN = process.env.HF_TOKEN;
  const apiUrl = 'https://router.huggingface.co/v1/chat/completions';
  if (!HF_TOKEN) throw new Error('HF_TOKEN not set in environment');

  const resp = await axios.post(apiUrl, body, {
    headers: { Authorization: `Bearer ${HF_TOKEN}`, 'Content-Type': 'application/json' },
    timeout: 90000
  });
  if (!resp.data) throw new Error('Empty response from HF router');
  const d = resp.data;
  let text = '';
  if (Array.isArray(d.choices) && d.choices.length > 0) {
    const ch = d.choices[0];
    if (ch.message && typeof ch.message.content === 'string') text = ch.message.content;
    else if (ch.text && typeof ch.text === 'string') text = ch.text;
    else text = JSON.stringify(ch);
  } else if (typeof d.output === 'string') {
    text = d.output;
  } else {
    text = JSON.stringify(d);
  }
  return text;
}

function extractJsonArray(text) {
  const first = text.indexOf('[');
  const last = text.lastIndexOf(']');
  if (first !== -1 && last !== -1 && last > first) {
    const jsonStr = text.slice(first, last + 1);
    return JSON.parse(jsonStr);
  }
  throw new Error('No JSON array found in model output');
}

// Фоллбек-генератор (скелет)
function simpleGenerateLessonsSkeleton(goalTitle, durationWeeks = 4, lessonsPerWeek = 2) {
  const base = (goalTitle || "Курс").trim();
  const keywords = base
    .split(/\s+/)
    .slice(0, 4)
    .map(w => w.replace(/[^а-яА-ЯёЁa-zA-Z0-9]/g, ""));
  const main = keywords.join(" ").trim() || base;

  const lessons = [];
  for (let w = 1; w <= durationWeeks; w++) {
    for (let l = 1; l <= lessonsPerWeek; l++) {
      lessons.push({
        week: w,
        lessonNumber: l,
        title: `${main} — Неделя ${w}, Занятие ${l}`
      });
    }
  }
  return lessons;
}

// Полный локальный фоллбек (теория + практика)
function simpleGenerateLessons(goalTitle, durationWeeks = 4, lessonsPerWeek = 2) {
  const base = (goalTitle || "Курс").trim();
  const keywords = base
    .split(/\s+/)
    .slice(0, 3)
    .map(w => w.replace(/[^а-яА-ЯёЁa-zA-Z0-9]/g, ""));
  const main = keywords.join(" ").trim() || base;

  const lessons = [];
  let lessonGlobalIdx = 1;
  for (let w = 1; w <= durationWeeks; w++) {
    for (let l = 1; l <= lessonsPerWeek; l++) {
      const title = `${main} — Неделя ${w}, Занятие ${l}`;
      const theory = `Короткая теория: ${title}. Ключевая идея: познакомиться с ${main} (шаг ${lessonGlobalIdx}).`;
      const practice = `Практика: выполните небольшое задание по теме "${title}".`;
      lessons.push({
        week: w,
        lessonNumber: l,
        title,
        theory,
        practice
      });
      lessonGlobalIdx++;
    }
  }
  return lessons;
}

// Генерирует "скелет" курса (только заголовки) — используется для длинных курсов
async function generateCourseSkeletonHf(goalTitle, durationWeeks = 8, lessonsPerWeek = 2) {
  const model = process.env.HF_MODEL;
  const systemMsg = 'You are an assistant that outputs ONLY valid JSON arrays. Use concise Russian. No extra text.';
  const prompt = `
You are an expert course designer. Generate only titles for a course with goal: "${goalTitle}".
Structure:
- weeks: ${durationWeeks}
- lessonsPerWeek: ${lessonsPerWeek}

Return EXACTLY a JSON array of objects:
[{"week":1,"lessonNumber":1,"title":"..."}, ...]
No theory, no practice, no extra text. Use concise Russian.
`;

  const body = {
    model,
    messages: [
      { role: 'system', content: systemMsg },
      { role: 'user', content: prompt }
    ],
    stream: false,
    max_new_tokens: 800,
    temperature: 0.2
  };

  try {
    const text = await callRouter(body);
    const parsed = extractJsonArray(text);
    if (!Array.isArray(parsed)) throw new Error('Parsed not array');
    return parsed.map(item => ({
      week: Number(item.week) || 1,
      lessonNumber: Number(item.lessonNumber) || 1,
      title: String(item.title || '').trim()
    }));
  } catch (err) {
    console.warn('generateCourseSkeletonHf failed, using fallback:', err.message || err);
    return simpleGenerateLessonsSkeleton(goalTitle, durationWeeks, lessonsPerWeek);
  }
}

async function generateDetailedLessonsForWeekHf(goalTitle, weekNumber, lessonsPerWeek = 2, longTheory = true) {
  const model = process.env.HF_MODEL;
  const systemMsg = 'You are an assistant that outputs ONLY valid JSON arrays. Use concise Russian. No extra text.';

  const theorySpec = longTheory
    ? 'Теория — один абзац (примерно 80-150 слов).'
    : 'Короткая теория — 2-4 предложения.';

  const prompt = `
Generate lessons for week ${weekNumber} of a course with goal: "${goalTitle}".
Weeks: ${weekNumber} (we only need this week's lessons).
LessonsPerWeek: ${lessonsPerWeek}.
${theorySpec}
Return EXACTLY a JSON array with objects:
[{"week":${weekNumber},"lessonNumber":1,"title":"...","theory":"...","practice":"..."}, ...]
No extra text, no explanation. Use concise Russian.
`;

  const body = {
    model,
    messages: [
      { role: 'system', content: systemMsg },
      { role: 'user', content: prompt }
    ],
    stream: false,
    max_new_tokens: 1500,
    temperature: 0.6
  };

  try {
    const text = await callRouter(body);
    const parsed = extractJsonArray(text);
    if (!Array.isArray(parsed)) throw new Error('Week parsed to non-array');

    return parsed.map(item => ({
      week: Number(item.week) || weekNumber,
      lessonNumber: Number(item.lessonNumber) || 1,
      title: String(item.title || '').trim(),
      theory: String(item.theory || '').trim(),
      practice: String(item.practice || '').trim()
    }));
  } catch (err) {
    console.warn(`generateDetailedLessonsForWeekHf failed for week ${weekNumber}:`, err.message || err);
    const base = (goalTitle || "Курс").trim();
    const lessons = [];
    for (let l = 1; l <= lessonsPerWeek; l++) {
      lessons.push({
        week: weekNumber,
        lessonNumber: l,
        title: `${base} — Неделя ${weekNumber}, Занятие ${l}`,
        theory: `Короткая теория: ${base} — неделя ${weekNumber}, занятие ${l}.`,
        practice: `Практика: выполните упражнение по теме "${base} — Неделя ${weekNumber}, Занятие ${l}".`
      });
    }
    return lessons;
  }
}

//авто генерация /шаблон генерации
function simpleGenerateLessons(goalTitle, durationWeeks = 4, lessonsPerWeek = 2) {
  const base = (goalTitle || "Курс").trim();
  const keywords = base
    .split(/\s+/)
    .slice(0, 3)
    .map(w => w.replace(/[^а-яА-ЯёЁa-zA-Z0-9]/g, ""));
  const main = keywords.join(" ").trim() || base;

  const lessons = [];
  let lessonGlobalIdx = 1;
  for (let w = 1; w <= durationWeeks; w++) {
    for (let l = 1; l <= lessonsPerWeek; l++) {
      const title = `${main} — Неделя ${w}, Занятие ${l}`;
      const theory = `Короткая теория: ${title}. Ключевая идея: познакомиться с ${main} (шаг ${lessonGlobalIdx}).`;
      const practice = `Практика: выполните небольшое задание по теме "${title}".`;
      lessons.push({
        week: w,
        lessonNumber: l,
        title,
        theory,
        practice
      });
      lessonGlobalIdx++;
    }
  }
  return lessons;
}

app.post("/courses/generate", authMiddleware, async (req, res) => {
  const { title } = req.body;
  let durationWeeks = Number(req.body.duration_weeks) || 4;
  let lessonsPerWeek = Number(req.body.lessons_per_week) || 2;
  if (isNaN(durationWeeks) || durationWeeks < 1) durationWeeks = 1;
  if (durationWeeks > 52) durationWeeks = 52;
  if (isNaN(lessonsPerWeek) || lessonsPerWeek < 1) lessonsPerWeek = 1;
  if (lessonsPerWeek > 7) lessonsPerWeek = 7;

  const userId = req.user.id;
  if (!title || title.trim().length === 0) return res.status(400).json({ error: "Требуется title" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const courseResult = await client.query(
      "INSERT INTO courses (user_id, title, duration_weeks) VALUES ($1, $2, $3) RETURNING id, title, duration_weeks, created_at",
      [userId, title, durationWeeks]
    );
    const courseId = courseResult.rows[0].id;

    for (let w = 1; w <= durationWeeks; w++) {
      const weekRes = await client.query(
        "INSERT INTO course_weeks (course_id, week_number) VALUES ($1, $2) RETURNING id",
        [courseId, w]
      );
      const weekId = weekRes.rows[0].id;

      if (durationWeeks <= 4) {
        let lessonsForWeek;
        try {
          lessonsForWeek = await generateDetailedLessonsForWeekHf(title, w, lessonsPerWeek, true);
        } catch (err) {
          console.warn(`HF failed for week ${w}, using simple generator:`, err.message || err);
          lessonsForWeek = simpleGenerateLessons(title, 1, lessonsPerWeek).filter(l => l.week === 1).map((l, idx) => ({
            ...l,
            week: w,
            lessonNumber: idx + 1
          }));
        }

        for (const l of lessonsForWeek) {
          await client.query(
            `INSERT INTO lessons (week_id, lesson_number, title, theory, practice)
             VALUES ($1, $2, $3, $4, $5)`,
            [weekId, l.lessonNumber, l.title, l.theory, l.practice]
          );
        }

      } else {
        let skeleton;
        try {
          skeleton = await generateCourseSkeletonHf(title, durationWeeks, lessonsPerWeek);
        } catch (err) {
          console.warn('Skeleton generation failed, using fallback skeleton:', err.message || err);
          skeleton = simpleGenerateLessonsSkeleton(title, durationWeeks, lessonsPerWeek);
        }

        const lessonsForWeek = skeleton.filter(s => Number(s.week) === w);

        if (!lessonsForWeek || lessonsForWeek.length === 0) {
          for (let lNum = 1; lNum <= lessonsPerWeek; lNum++) {
            await client.query(
              `INSERT INTO lessons (week_id, lesson_number, title, theory, practice)
               VALUES ($1, $2, $3, $4, $5)`,
              [weekId, lNum, `Занятие ${lNum}`, '', '']
            );
          }
        } else {
          for (const s of lessonsForWeek) {
            await client.query(
              `INSERT INTO lessons (week_id, lesson_number, title, theory, practice)
               VALUES ($1, $2, $3, $4, $5)`,
              [weekId, s.lessonNumber, s.title, '', ''] 
            );
          }
        }
      }
    }

    await client.query("COMMIT");

    if (durationWeeks <= 4) {
      res.json({
        message: "Курс успешно создан (полный контент сгенерирован)",
        course: { id: courseId, title: courseResult.rows[0].title, duration_weeks: durationWeeks }
      });
    } else {
      res.json({
        message: "Курс успешно создан (скелет курса сгенерирован). Детали уроков можно догенерировать по неделям.",
        course: { id: courseId, title: courseResult.rows[0].title, duration_weeks: durationWeeks },
        lazy_generation_endpoint: `/courses/${courseId}/weeks/:weekNumber/generate`
      });
    }
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("Generate course error:", err);
    res.status(500).json({ error: "Ошибка генерации курса" });
  } finally {
    client.release();
  }
});


app.get("/courses", authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, title, duration_weeks, created_at, progress, is_completed
       FROM courses WHERE user_id = $1 ORDER BY created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("Get courses error:", err);
    res.status(500).json({ error: "Ошибка получения курсов" });
  }
});

app.get("/courses/:id", authMiddleware, async (req, res) => {
  const courseId = req.params.id;
  try {
    const courseRes = await pool.query("SELECT id, title, duration_weeks, created_at FROM courses WHERE id = $1 AND user_id = $2", [courseId, req.user.id]);
    if (courseRes.rows.length === 0) return res.status(404).json({ error: "Курс не найден" });

    const weeksRes = await pool.query("SELECT id, week_number FROM course_weeks WHERE course_id = $1 ORDER BY week_number", [courseId]);
    const weeks = [];
    for (const wk of weeksRes.rows) {
      const lessonsRes = await pool.query(
        "SELECT id, lesson_number, title, theory, practice, completed FROM lessons WHERE week_id = $1 ORDER BY lesson_number",
        [wk.id]
      );
      weeks.push({ id: wk.id, week_number: wk.week_number, lessons: lessonsRes.rows });
    }

    res.json({ course: courseRes.rows[0], weeks });
  } catch (err) {
    console.error("Get course detail error:", err);
    res.status(500).json({ error: "Ошибка получения курса" });
  }
});


app.patch("/lessons/:id/complete", authMiddleware, async (req, res) => {
  const lessonId = Number(req.params.id);
  const completed = req.body.completed === true;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const upd = await client.query(
      `UPDATE lessons l SET completed = $1
       FROM course_weeks cw
       JOIN courses c ON cw.course_id = c.id
       WHERE l.week_id = cw.id AND l.id = $2 AND c.user_id = $3
       RETURNING l.id, l.week_id, c.id AS course_id, l.completed`,
      [completed, lessonId, req.user.id]
    );

    if (upd.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Урок не найден или нет доступа" });
    }

    const courseId = upd.rows[0].course_id;

    const cnt = await client.query(
      `SELECT COUNT(*)::int AS total,
              SUM(CASE WHEN l.completed THEN 1 ELSE 0 END)::int AS completed
       FROM lessons l
       JOIN course_weeks cw ON l.week_id = cw.id
       WHERE cw.course_id = $1`,
      [courseId]
    );
    const total = Number(cnt.rows[0].total || 0);
    const completedCount = Number(cnt.rows[0].completed || 0);
    const progress = total > 0 ? Math.round((completedCount / total) * 100) : 0;
    const isCompleted = progress === 100;

    await client.query(
      `UPDATE courses SET progress = $1, is_completed = $2 WHERE id = $3`,
      [progress, isCompleted, courseId]
    );

    await client.query("COMMIT");

    res.json({
      lesson: { id: upd.rows[0].id, completed: !!upd.rows[0].completed },
      course_progress: progress,
      is_completed: isCompleted
    });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("Complete lesson error:", err);
    res.status(500).json({ error: "Ошибка обновления статуса урока" });
  } finally {
    client.release();
  }
});


app.post("/courses/:courseId/weeks/:weekNumber/generate", authMiddleware, async (req, res) => {
  const courseId = Number(req.params.courseId);
  const weekNumber = Number(req.params.weekNumber);
  const lessonsPerWeek = Number(req.body.lessons_per_week) || undefined;
  const longTheory = req.body.longTheory !== undefined ? Boolean(req.body.longTheory) : true;

  try {
    const courseCheck = await pool.query("SELECT id, title, duration_weeks FROM courses WHERE id = $1 AND user_id = $2", [courseId, req.user.id]);
    if (courseCheck.rows.length === 0) return res.status(404).json({ error: "Курс не найден или нет доступа" });
    const course = courseCheck.rows[0];

    const weekRes = await pool.query("SELECT id FROM course_weeks WHERE course_id = $1 AND week_number = $2", [courseId, weekNumber]);
    if (weekRes.rows.length === 0) return res.status(404).json({ error: "Неделя не найдена" });
    const weekId = weekRes.rows[0].id;

    let lessonsCount = lessonsPerWeek;
    if (!lessonsCount) {
      const cnt = await pool.query("SELECT COUNT(*) FROM lessons WHERE week_id = $1", [weekId]);
      lessonsCount = Number(cnt.rows[0].count) || 1;
    }

    const detailed = await generateDetailedLessonsForWeekHf(course.title, weekNumber, lessonsCount, longTheory);

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      for (const l of detailed) {
        const upd = await client.query(
          `UPDATE lessons SET title = $1, theory = $2, practice = $3
           WHERE week_id = $4 AND lesson_number = $5
           RETURNING id`,
          [l.title, l.theory, l.practice, weekId, l.lessonNumber]
        );
        if (upd.rows.length === 0) {
          await client.query(
            `INSERT INTO lessons (week_id, lesson_number, title, theory, practice)
             VALUES ($1, $2, $3, $4, $5)`,
            [weekId, l.lessonNumber, l.title, l.theory, l.practice]
          );
        }
      }
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }

    res.json({ message: `Детали недели ${weekNumber} успешно сгенерированы` });
  } catch (err) {
    console.error("Lazy generate week error:", err);
    res.status(500).json({ error: "Ошибка генерации деталей недели" });
  }
});



app.listen(port, "0.0.0.0", () => {
  console.log(`API running on http://0.0.0.0:${port}`);
});
