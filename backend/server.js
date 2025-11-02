// server.js
const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(express.json());
app.use(cors());

mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB connected"))
  .catch(err => console.error("MongoDB connection error:", err));

/**
 * User schema (твой существующий)
 */
const userSchema = new mongoose.Schema({
  username: String,
  email: { type: String, unique: true, index: true },
  password: String
}, { timestamps: true });

const User = mongoose.model("User", userSchema);

/**
 * Trainings schema
 * простая, понятная структура для тренировки/сценария
 */
const choiceSchema = new mongoose.Schema({
  id: String, // локальный id выбора, например "a", "b"
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
  type: String, // 'пожар', 'затопление' и т.д.
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
    totalChoices: Number // можно посчитать при создании/обновлении
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
 * - ожидает заголовок Authorization: "Bearer <token>"
 * - после верификации кладёт req.userId
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
 * Auth routes: register / login
 */
app.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body;
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ message: "Пользователь уже существует" });

    const hash = await bcrypt.hash(password, 10);
    const newUser = new User({ username, email, password: hash });
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

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.json({ message: "Успешный вход", token });
  } catch (err) {
    res.status(500).json({ message: "Ошибка сервера" });
  }
});

/**
 * Пользователи
 */
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

/**
 * Trainings endpoints
 *
 * GET /trainings               - список (фильтры: type, tag, isPublished)
 * GET /trainings/:id           - получить один сценарий
 * POST /trainings              - создать (auth)
 * PUT  /trainings/:id          - обновить (auth, желательно автор)
 * DELETE /trainings/:id        - удалить (auth, желательно автор)
 * POST /trainings/:id/attempt  - отправить результат прохождения (auth)
 */

/** List trainings с простыми фильтрами */
app.get("/trainings", async (req, res) => {
  try {
    const { type, tag, isPublished, q, limit = 20, skip = 0 } = req.query;
    const filter = {};
    if (type) filter.type = type;
    if (typeof isPublished !== "undefined") filter.isPublished = isPublished === "true";
    if (tag) filter.tags = tag;
    if (q) filter.$text = { $search: q }; // если добавишь text index — будет работать

    const trainings = await Training.find(filter)
      .select("-scenes.choices.consequenceText") // можно скрыть подсказки/тексты последствий при листинге
      .limit(Math.min(100, parseInt(limit)))
      .skip(parseInt(skip))
      .sort({ createdAt: -1 });

    res.json(trainings);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при получении тренингов" });
  }
});

/** Get one training */
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

/** Create training (auth) */
app.post("/trainings", authMiddleware, async (req, res) => {
  try {
    const payload = req.body;
    // базовая валидация: title и сцены
    if (!payload.title) return res.status(400).json({ message: "Не указан title" });
    if (!Array.isArray(payload.scenes) || payload.scenes.length === 0) {
      return res.status(400).json({ message: "Необходимо как минимум одна сцена" });
    }

    // подсчитать totalChoices автоматически
    const totalChoices = payload.scenes.length;

    const training = new Training({
      ...payload,
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

/** Update training (auth) - простая реализация, без проверки прав (можно добавить проверку createdBy) */
app.put("/trainings/:id", authMiddleware, async (req, res) => {
  try {
    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    // Если нужно — проверять что req.userId == training.createdBy.toString()
    // if (training.createdBy && training.createdBy.toString() !== req.userId) return res.status(403).json({ message: "Нет прав" });

    Object.assign(training, req.body);

    // если сцены изменились — обновим totalChoices
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

/** Delete training (auth) */
app.delete("/trainings/:id", authMiddleware, async (req, res) => {
  try {
    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    // при желании добавь проверку на автора
    // if (training.createdBy && training.createdBy.toString() !== req.userId) return res.status(403).json({ message: "Нет прав" });

    await Training.deleteOne({ _id: req.params.id });
    res.json({ message: "Тренировка удалена" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при удалении тренировки" });
  }
});

/**
 * POST /trainings/:id/attempt
 * body: { choices: [{ sceneId: number, choiceId: string }], timeSec: number }
 * Возвращает: подсчитанный результат и обновляет stats в training
 */
app.post("/trainings/:id/attempt", authMiddleware, async (req, res) => {
  try {
    const { choices, timeSec } = req.body;
    if (!Array.isArray(choices)) return res.status(400).json({ message: "Неверные данные попытки" });

    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    // подготовка map для быстрого доступа к сценам/выборам
    const sceneMap = new Map();
    for (const s of training.scenes) {
      const choiceMap = new Map();
      for (const c of s.choices) choiceMap.set(c.id, c);
      sceneMap.set(s.id, { scene: s, choices: choiceMap });
    }

    // подсчёт результатов
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

    // итоги
    const totalChoices = training.summaryMetrics?.totalChoices ?? training.scenes.length;
    const success = (correctAnswers === totalChoices);

    // обновляем stats: attempts++, successes++ если success, пересчитываем avgTimeSec как скользящая средняя
    const prevAttempts = training.stats.attempts || 0;
    const prevAvg = training.stats.avgTimeSec || 0;
    const newAttempts = prevAttempts + 1;
    const newAvgTime = prevAvg === 0 ? (timeSec || 0) : Math.round(((prevAvg * prevAttempts) + (timeSec || 0)) / newAttempts);

    training.stats.attempts = newAttempts;
    if (success) training.stats.successes = (training.stats.successes || 0) + 1;
    training.stats.avgTimeSec = newAvgTime;

    await training.save();

    res.json({
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
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при записи попытки" });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
