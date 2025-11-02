// server.js
const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");
require("dotenv").config();
const axios = require("axios");

const app = express();
app.use(express.json());
app.use(cors());

mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB connected"))
  .catch(err => console.error("MongoDB connection error:", err));

/**
 * Schemas
 */
const userSchema = new mongoose.Schema({
  username: { type: String, default: "" },
  email: { type: String, unique: true, index: true, required: true },
  password: { type: String, required: true }, // хранится хэш
  avatarUrl: { type: String, default: "" }, // ссылка на аватар
  stats: {
    totalAttempts: { type: Number, default: 0 },
    successes: { type: Number, default: 0 },
    avgScore: { type: Number, default: 0 },   // можно пересчитывать при каждой попытке
    totalTimeSec: { type: Number, default: 0 }
  },
  achievements: [
    {
      code: String,      // машинный код бейджа, например "fire_master_1"
      title: String,     // человекочитаемое название
      earnedAt: Date
    }
  ],
  lastActiveAt: { type: Date, default: Date.now } // обновлять при логине/действии
}, { timestamps: true }); // createdAt / updatedAt автоматически

const User = mongoose.model("User", userSchema);

const choiceSchema = new mongoose.Schema({
  id: String,
  text: String,
  consequenceType: { type: String, enum: ["correct", "warning", "fatal", "neutral"], default: "neutral" },
  consequenceText: String,
  scoreDelta: { type: Number, default: 0 }
}, { _id: false });

const sceneSchema = new mongoose.Schema({
  id: Number,
  title: String,
  description: String,
  hint: String,
  choices: [choiceSchema],
  defaultChoiceId: String
}, { _id: false });

const trainingSchema = new mongoose.Schema({
  title: { type: String, required: true },
  summary: String,
  type: String,
  location: {
    name: String,
    floor: String,
    extra: String
  },
  difficulty: { type: String, enum: ["easy","medium","hard"], default: "medium" },
  aiGenerated: { type: Boolean, default: false },
  aiMeta: {
    model: String,
    promptSeed: String,
    version: String
  },
  durationEstimateSec: Number,
  scenes: [sceneSchema],
  summaryMetrics: {
    totalChoices: Number
  },
  stats: {
    attempts: { type: Number, default: 0 },
    successes: { type: Number, default: 0 },
    avgTimeSec: { type: Number, default: 0 }
  },
  tags: [String],
  assets: [String],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
  isPublished: { type: Boolean, default: false }
}, { timestamps: true });

const Training = mongoose.model("Training", trainingSchema);

/**
 * Auth middleware
 */
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ message: "Токен отсутствует" });

  try{
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.id;
    next();
  }catch(err){
    res.status(403).json({message: "Неверный или истекший токен"});
  }
}

/**
 * Hugging Face Router helper + parsers + fallbacks
 */
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

// Попытка извлечь первый валидный JSON-объект из текста (на случай, если модель вернёт объект)
function extractJsonObject(text) {
  // Try parse whole text first
  try {
    return JSON.parse(text);
  } catch (e) {}
  const first = text.indexOf('{');
  const last = text.lastIndexOf('}');
  if (first !== -1 && last !== -1 && last > first) {
    const jsonStr = text.slice(first, last + 1);
    return JSON.parse(jsonStr);
  }
  throw new Error('No JSON object found in model output');
}

/**
 * Генерирует полностью структуру тренировки (title, summary, scenes)
 * Поле title может быть пустым — модель должна сгенерировать подходящий заголовок на основе type/location.
 */
async function generateTrainingHf({ title, type, location, scenesCount = 5, choicesPerScene = 3 }) {
  const model = process.env.HF_MODEL;
  const systemMsg = 'You are an assistant that outputs ONLY valid JSON. Use concise Russian. No extra text.';
  // Compose context summary for prompt
  const ctx = [];
  if (type) ctx.push(`Тип ЧС: "${type}"`);
  if (location && (location.name || location.floor || location.extra)) {
    const locParts = [location.name, location.floor, location.extra].filter(Boolean).join(', ');
    ctx.push(`Локация: "${locParts}"`);
  }
  const ctxLine = ctx.length ? ctx.join(' | ') : 'Без дополнительных входных данных — придумай реалистичный сценарий';
  const prompt = `
Generate EXACTLY one JSON OBJECT describing a full training suitable for emergency simulation UI. Use concise Russian. No commentary, only JSON.

Context: ${ctxLine}

Required structure:
{
  "title":"Short title for the training",
  "summary":"One-sentence summary describing training goal",
  "location": { "name":"...", "floor":"...", "extra":"..." }, // can be empty strings if unknown
  "difficulty":"easy|medium|hard",
  "scenes": [ ... array of ${scenesCount} scene objects ... ]
}

Each scene object must have:
{
  "id": number (1..${scenesCount}),
  "title":"short title",
  "description":"paragraph describing the situation",
  "hint":"1-2 sentence hint",
  "choices":[
    { "id":"a","text":"...","consequenceType":"correct|warning|fatal|neutral","consequenceText":"...","scoreDelta": integer },
    ...
  ],
  "defaultChoiceId":"a"
}

Return exactly one JSON object. Use ${choicesPerScene} choices per scene. Make one choice per scene "correct".
`;

  const body = {
    model,
    messages: [
      { role: 'system', content: systemMsg },
      { role: 'user', content: prompt }
    ],
    stream: false,
    max_new_tokens: 1400,
    temperature: 0.25
  };

  try {
    const text = await callRouter(body);
    // Try parse object first, fallback to array-based parsing inside scenes
    let parsed = null;
    try {
      parsed = extractJsonObject(text);
    } catch (e) {
      // as a last resort, try find array and wrap into object
      try {
        const arr = extractJsonArray(text);
        parsed = { title: title || '', summary: '', location: {}, difficulty: 'medium', scenes: arr };
      } catch (ee) {
        throw new Error('Cannot parse model output as JSON object or array');
      }
    }

    // Normalize result
    const result = {
      title: String(parsed.title || (title ? title : `Тренировка — ${type || 'Обучение'}`)).trim(),
      summary: String(parsed.summary || '').trim(),
      location: parsed.location || (location || { name: '', floor: '', extra: '' }),
      difficulty: parsed.difficulty || 'medium',
      scenes: Array.isArray(parsed.scenes) ? parsed.scenes.map((it, idx) => {
        const choices = Array.isArray(it.choices) ? it.choices.map((c, ci) => ({
          id: String(c.id || String.fromCharCode(97 + ci)),
          text: String(c.text || '').trim(),
          consequenceType: String(c.consequenceType || 'neutral').trim(),
          consequenceText: String(c.consequenceText || '').trim(),
          scoreDelta: Number(c.scoreDelta || 0)
        })) : [];
        return {
          id: Number(it.id) || (idx + 1),
          title: String(it.title || `Сцена ${idx+1}`).trim(),
          description: String(it.description || '').trim(),
          hint: String(it.hint || '').trim(),
          choices,
          defaultChoiceId: String(it.defaultChoiceId || (choices.length ? choices[0].id : 'a'))
        };
      }) : []
    };

    // If scenes are missing or count mismatch, fallback to local generator
    if (!Array.isArray(result.scenes) || result.scenes.length < 1) {
      throw new Error('No scenes produced by model');
    }

    return result;
  } catch (err) {
    console.warn('generateTrainingHf failed, using fallback:', err.message || err);
    // Fallback: build object with generated scenes by local generator
    const fallbackScenes = simpleGenerateScenes(title || (type ? `${type} тренировка` : 'Сценарий'), scenesCount, choicesPerScene);
    return {
      title: title || (type ? `Тренировка: ${type}` : 'Учебная тренировка'),
      summary: title ? `${title} — сгенерированная тренировка` : `Тренировка по ${type || 'общему сценарию'}`,
      location: location || { name: '', floor: '', extra: '' },
      difficulty: 'medium',
      scenes: fallbackScenes
    };
  }
}


/** Local fallback: simple skeleton (titles only) */
function simpleGenerateScenesSkeleton(title, scenesCount = 5, choicesPerScene = 3) {
  const base = (title || "Сценарий").trim();
  const scenes = [];
  for (let i = 1; i <= scenesCount; i++) {
    const choices = [];
    for (let c = 0; c < choicesPerScene; c++) {
      const id = String.fromCharCode(97 + c); // a, b, c...
      choices.push({
        id,
        text: `Вариант ${id.toUpperCase()} для сцены ${i}`,
        consequenceType: "neutral",
        consequenceText: "",
        scoreDelta: 0
      });
    }
    scenes.push({
      id: i,
      title: `${base} — Сцена ${i}`,
      description: `Короткое описание для сцены ${i}.`,
      hint: `Подсказка для сцены ${i}.`,
      choices,
      defaultChoiceId: choices[0].id
    });
  }
  return scenes;
}

/** Local full fallback (theory + practice style -> here: descriptions + choices) */
function simpleGenerateScenes(title, scenesCount = 5, choicesPerScene = 3) {
  const base = (title || "Сценарий").trim();
  const scenes = [];
  for (let i = 1; i <= scenesCount; i++) {
    const choices = [];
    for (let c = 0; c < choicesPerScene; c++) {
      const id = String.fromCharCode(97 + c);
      const isCorrect = c === 0; // первый вариант — корректный по умолчанию
      choices.push({
        id,
        text: isCorrect ? `Правильное действие ${id.toUpperCase()} при ситуации ${i}` : `Неправильное/менее удачное действие ${id.toUpperCase()} при ситуации ${i}`,
        consequenceType: isCorrect ? "correct" : (c === 1 ? "warning" : "fatal"),
        consequenceText: isCorrect ? `Это безопасный и рекомендованный вариант.` : (c === 1 ? "Это рискованно — приведёт к замедлению эвакуации." : "Это опасно — возможны жертвы."),
        scoreDelta: isCorrect ? 10 : (c === 1 ? -2 : -10)
      });
    }
    scenes.push({
      id: i,
      title: `${base} — Сцена ${i}`,
      description: `Подробное описание ситуации ${i}, где участнику нужно принять решение в условиях ограниченного времени.`,
      hint: `Подумайте о безопасности людей и возможных путях эвакуации.`,
      choices,
      defaultChoiceId: choices[0].id
    });
  }
  return scenes;
}

/** Generate scenes via HF Router */
async function generateScenesHf(title, scenesCount = 5, choicesPerScene = 3) {
  const model = process.env.HF_MODEL;
  const systemMsg = 'You are an assistant that outputs ONLY valid JSON arrays. Use concise Russian. No extra text.';
  const prompt = `
Generate EXACTLY a JSON array of scene objects for a training with title: "${title}".
Return an array with ${scenesCount} objects. Each object must have:
- id: number (1..${scenesCount})
- title: short title (string)
- description: one paragraph describing the scene/situation
- hint: 1-2 sentence hint for the participant
- choices: an array with ${choicesPerScene} objects, each having:
  - id: string ("a","b","c",...)
  - text: short text of the choice
  - consequenceType: one of "correct","warning","fatal","neutral"
  - consequenceText: one short sentence describing consequence
  - scoreDelta: integer (can be negative or positive)
- defaultChoiceId: the id of a default choice (e.g. "a")

Do NOT output any explanation or extra text — ONLY the JSON array.
Example element:
{"id":1,"title":"...","description":"...","hint":"...","choices":[{"id":"a","text":"...","consequenceType":"correct","consequenceText":"...","scoreDelta":10}, ...],"defaultChoiceId":"a"}
`;

  const body = {
    model,
    messages: [
      { role: 'system', content: systemMsg },
      { role: 'user', content: prompt }
    ],
    stream: false,
    max_new_tokens: 1200,
    temperature: 0.25
  };

  try {
    const text = await callRouter(body);
    const parsed = extractJsonArray(text);
    if (!Array.isArray(parsed)) throw new Error('Parsed not array');
    // Normalize parsed items
    const scenes = parsed.map((it, idx) => {
      const choices = Array.isArray(it.choices) ? it.choices.map((c, ci) => ({
        id: String(c.id || String.fromCharCode(97 + ci)),
        text: String(c.text || '').trim(),
        consequenceType: (String(c.consequenceType || 'neutral')).trim(),
        consequenceText: String(c.consequenceText || '').trim(),
        scoreDelta: Number(c.scoreDelta || 0)
      })) : [];
      return {
        id: Number(it.id) || (idx + 1),
        title: String(it.title || `Сцена ${idx+1}`).trim(),
        description: String(it.description || '').trim(),
        hint: String(it.hint || '').trim(),
        choices,
        defaultChoiceId: String(it.defaultChoiceId || (choices.length ? choices[0].id : 'a'))
      };
    });
    return scenes;
  } catch (err) {
    console.warn('generateScenesHf failed, using fallback:', err.message || err);
    // fallback to full generator
    return simpleGenerateScenes(title, scenesCount, choicesPerScene);
  }
}

/**
 * Auth routes (register/login) and users/profile
 */
app.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body;
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ message: "Пользователь уже существует" });

    const hash = await bcrypt.hash(password, 10);
    const newUser = new User({
      username,
      email,
      password: hash,
      avatarUrl: "",
      stats: { totalAttempts: 0, successes: 0, avgScore: 0, totalTimeSec: 0 },
      achievements: [],
      lastActiveAt: new Date()
    });
    await newUser.save();


    const token = jwt.sign({ id: newUser._id }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.status(201).json({ message: "Регистрация успешна", token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка сервера" });
  }
});

app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "Неверный email или пароль" });

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(400).json({ message: "Неверный email или пароль" });

    await User.findByIdAndUpdate(user._id, { lastActiveAt: new Date() });
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.json({ message: "Успешный вход", token });

  } catch (err) {
    res.status(500).json({ message: "Ошибка сервера" });
  }
});

app.get("/users", async(req, res) =>{
  try{
    const users = await User.find({}, "-password");
    res.json(users);
  }catch(err){
    res.status(500).json({message: "Ошибка при получении пользователей"});
  }
});

app.get("/profile", authMiddleware, async(req, res) =>{
  try{
    const user = await User.findById(req.userId, "-password");
    if (!user) return res.status(404).json({message: "Пользователь не найден"});
    res.json(user);
  }catch(err){
    res.status(500).json({message: "Ошибка при получении данных профиля"});
  }
});
app.patch("/profile", authMiddleware, async (req, res) => {
  try {
    const allowed = ["username", "avatarUrl"];
    const updates = {};
    for (const k of allowed) if (typeof req.body[k] !== "undefined") updates[k] = req.body[k];

    const user = await User.findByIdAndUpdate(req.userId, updates, { new: true, select: "-password" });
    if (!user) return res.status(404).json({ message: "Пользователь не найден" });
    res.json(user);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при обновлении профиля" });
  }
});
app.post("/profile/achievements", authMiddleware, async (req, res) => {
  try {
    const { code, title } = req.body;
    if (!code || !title) return res.status(400).json({ message: "Нужны code и title" });

    const ach = { code, title, earnedAt: new Date() };
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: "Пользователь не найден" });

    // избегаем дубликатов по code
    if (!user.achievements.some(a => a.code === code)) {
      user.achievements.push(ach);
      await user.save();
    }

    const out = user.toObject();
    delete out.password;
    res.json(out);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при добавлении достижения" });
  }
});


/**
 * Trainings endpoints
 */

/** List trainings */
app.get("/trainings", async (req, res) => {
  try {
    const { type, tag, isPublished, q, limit = 20, skip = 0 } = req.query;
    const filter = {};
    if (type) filter.type = type;
    if (typeof isPublished !== "undefined") filter.isPublished = isPublished === "true";
    if (tag) filter.tags = tag;
    if (q) filter.$text = { $search: q };

    const trainings = await Training.find(filter)
      .limit(Math.min(100, parseInt(limit)))
      .skip(parseInt(skip))
      .sort({ createdAt: -1 });

    res.json(trainings);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при получении тренингов" });
  }
});

/** Create training (auth) — с интеграцией AI (если нужно) */
app.post("/trainings", authMiddleware, async (req, res) => {
  try {
    const payload = req.body || {};
    // If user provided title — keep, otherwise we'll ask HF to generate if aiGenerate true
    const defaultScenesCount = Number(process.env.DEFAULT_SCENES) || 5;
    const scenesCount = Number(payload.scenesCount) || defaultScenesCount;
    const choicesPerScene = Number(payload.choicesPerScene) || 3;

    let scenes = Array.isArray(payload.scenes) ? payload.scenes : [];
    let aiMeta = { model: null, promptSeed: null, version: null };
    let aiGeneratedFlag = false;

    // If aiGenerate requested, call HF to produce (possibly generating title/summary/location too)
    if (payload.aiGenerate) {
      // call HF to produce full training structure; we pass title/type/location if present
      const hfResult = await generateTrainingHf({
        title: payload.title || '',
        type: payload.type || '',
        location: payload.location || {},
        scenesCount,
        choicesPerScene
      });

      // Use HF title/summary/location/difficulty if user didn't provide them
      const finalTitle = payload.title || hfResult.title;
      const finalSummary = payload.summary || hfResult.summary;
      const finalLocation = payload.location && Object.keys(payload.location).length ? payload.location : hfResult.location;
      const finalDifficulty = payload.difficulty || hfResult.difficulty || 'medium';

      // take scenes from HF unless user explicitly provided scenes
      scenes = Array.isArray(payload.scenes) && payload.scenes.length ? payload.scenes : (hfResult.scenes || []);

      aiGeneratedFlag = true;
      aiMeta = { model: process.env.HF_MODEL || null, promptSeed: payload.title || payload.type || null, version: new Date().toISOString() };

      // build training object
      const totalChoices = scenes.reduce((acc, s) => acc + (Array.isArray(s.choices) ? s.choices.length : 0), 0);
      const training = new Training({
        title: finalTitle,
        summary: finalSummary,
        type: payload.type || payload.type, // keep user-provided type if any
        location: finalLocation,
        difficulty: finalDifficulty,
        scenes,
        aiGenerated: aiGeneratedFlag,
        aiMeta,
        summaryMetrics: { totalChoices },
        createdBy: req.userId,
        tags: payload.tags || []
      });

      await training.save();
      return res.status(201).json(training);
    }

    // If aiGenerate not requested:
    // - if user provided scenes -> use them
    // - if not provided -> create skeleton local fallback
    if (!Array.isArray(scenes) || scenes.length === 0) {
      scenes = simpleGenerateScenesSkeleton(payload.title || (payload.type ? `Тренировка: ${payload.type}` : 'Сценарий'), scenesCount, choicesPerScene);
    }

    const totalChoices = scenes.reduce((acc, s) => acc + (Array.isArray(s.choices) ? s.choices.length : 0), 0);
    const training = new Training({
      ...payload,
      scenes,
      aiGenerated: false,
      aiMeta,
      summaryMetrics: { totalChoices },
      createdBy: req.userId
    });

    await training.save();
    res.status(201).json(training);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при создании тренировки" });
  }
});


/** Update training */
app.put("/trainings/:id", authMiddleware, async (req, res) => {
  try {
    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    Object.assign(training, req.body);

    if (Array.isArray(req.body.scenes)) {
      training.summaryMetrics = { totalChoices: req.body.scenes.length };
    }

    await training.save();
    res.json(training);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при обновлении тренировки" });
  }
});

/** Delete training */
app.delete("/trainings/:id", authMiddleware, async (req, res) => {
  try {
    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    await Training.deleteOne({ _id: req.params.id });
    res.json({ message: "Тренировка удалена" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при удалении тренировки" });
  }
});

/** Attempt endpoint — обновлённый: записывает stats в тренировку и в профиль пользователя */
app.post("/trainings/:id/attempt", authMiddleware, async (req, res) => {
  try {
    const { choices, timeSec } = req.body;
    if (!Array.isArray(choices)) return res.status(400).json({ message: "Неверные данные попытки" });

    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    // Построим карту сцен/вариантов
    const sceneMap = new Map();
    for (const s of training.scenes) {
      const choiceMap = new Map();
      for (const c of s.choices) choiceMap.set(c.id, c);
      sceneMap.set(s.id, { scene: s, choices: choiceMap });
    }

    let totalScore = 0;
    let correctAnswers = 0;
    let totalScenesConsidered = 0;
    const details = [];

    for (const userChoice of choices) {
      const { sceneId, choiceId } = userChoice;
      const sm = sceneMap.get(sceneId);
      if (!sm) {
        details.push({ sceneId, ok: false, reason: "Сцена не найдена" });
        continue;
      }
      totalScenesConsidered++;
      const choice = sm.choices.get(choiceId);
      if (!choice) {
        details.push({ sceneId, ok: false, reason: "Выбор не найден" });
        continue;
      }

      totalScore += (choice.scoreDelta || 0);
      if (choice.consequenceType === "correct") correctAnswers++;
      details.push({
        sceneId,
        choiceId,
        consequenceType: choice.consequenceType,
        scoreDelta: choice.scoreDelta
      });
    }

    const totalScenes = Array.isArray(training.scenes) ? training.scenes.length : 0;
    const success = (correctAnswers === totalScenes) || (correctAnswers === totalScenesConsidered);
    const totalChoices = totalScenes;

    // Обновляем статистику тренировки
    const prevAttempts = training.stats.attempts || 0;
    const prevAvg = training.stats.avgTimeSec || 0;
    const newAttempts = prevAttempts + 1;
    const newAvgTime = prevAvg === 0 ? (timeSec || 0) : Math.round(((prevAvg * prevAttempts) + (timeSec || 0)) / newAttempts);

    training.stats.attempts = newAttempts;
    if (success) training.stats.successes = (training.stats.successes || 0) + 1;
    training.stats.avgTimeSec = newAvgTime;

    await training.save();

    // --------- Обновляем статистику пользователя ----------
    const user = await User.findById(req.userId);
    if (user) {
      const uStats = user.stats || { totalAttempts: 0, successes: 0, avgScore: 0, totalTimeSec: 0 };
      const prevUserAttempts = uStats.totalAttempts || 0;
      const prevUserAvgScore = typeof uStats.avgScore === "number" ? uStats.avgScore : 0;
      const newUserAttempts = prevUserAttempts + 1;
      // Средний балл пользователя пересчитываем по totalScore (можно выбрать другую метрику)
      const newAvgScore = prevUserAttempts === 0
        ? totalScore
        : ( (prevUserAvgScore * prevUserAttempts) + totalScore ) / newUserAttempts;
      const roundedAvgScore = Math.round(newAvgScore * 100) / 100; // 2 знака

      user.stats.totalAttempts = newUserAttempts;
      user.stats.avgScore = roundedAvgScore;
      user.stats.totalTimeSec = (uStats.totalTimeSec || 0) + (timeSec || 0);
      if (success) user.stats.successes = (uStats.successes || 0) + 1;

      // Обновляем lastActiveAt
      user.lastActiveAt = new Date();

      // Простое достижение: первая успешная попытка
      if (success && !(user.achievements || []).some(a => a.code === 'first_success')) {
        user.achievements = user.achievements || [];
        user.achievements.push({ code: 'first_success', title: 'Первая успешная тренировка', earnedAt: new Date() });
      }

      await user.save();
    }

    // Ответ клиенту — с результатом и обновлённой статистикой тренировки (и опционально статистикой пользователя)
    const response = {
      message: "Результат записан",
      result: {
        totalScore,
        correctAnswers,
        totalChoices,
        success,
        timeSec: timeSec || null,
        details
      },
      updatedStats: training.stats
    };

    // Добавим краткую статистику пользователя в ответ, если пользователь найден
    if (user) {
      const userSafe = {
        id: user._id,
        stats: user.stats,
        achievementsCount: (user.achievements || []).length,
        lastActiveAt: user.lastActiveAt
      };
      response.userStats = userSafe;
    }

    res.json(response);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при записи попытки" });
  }
});


/** List trainings of the current authenticated user */
app.get("/trainings/mine", authMiddleware, async (req, res) => {
  try {
    const { type, tag, isPublished, limit = 20, skip = 0 } = req.query;

    // Базовый фильтр — только записи этого пользователя
    const filter = { createdBy: req.userId };
    // const t = await Training.findById(req.params.id).populate("createdBy", "username email");
    if (type) filter.type = type;
    if (typeof isPublished !== "undefined") filter.isPublished = isPublished === "true";
    if (tag) filter.tags = tag;
    // Можно добавить другие фильтры по необходимости

    const trainings = await Training.find(filter).populate("createdBy", "username email")
      .limit(Math.min(100, parseInt(limit)))
      .skip(parseInt(skip))
      .sort({ createdAt: -1 });

    res.json(trainings);
  } catch (err) {
    console.error("Error /trainings/mine:", err);
    res.status(500).json({ message: "Ошибка при получении ваших тренингов" });
  }
});

/** Get one training ВСЕГДА ДОЛЖЕН БЫТЬ НИЖЕ ВСЕХ РОУТОВ!*/ 
app.get("/trainings/:id", async (req, res) => {
  try {
    const t = await Training.findById(req.params.id).populate("createdBy", "username email");
    if (!t) return res.status(404).json({ message: "Тренировка не найдена" });
    res.json(t);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при получении тренировки" });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
