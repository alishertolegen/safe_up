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

const userSchema = new mongoose.Schema({
  username: String,
  email: String,
  password: String
});

const User = mongoose.model("User", userSchema);

function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ message: "Токен отсутствует" });

  try{
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.id;
    next();
  }catch(err){
    res.status(403).json({message: "Неверный или истекший токен"})
  }
}

app.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body;

    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ message: "Пользователь уже существует" });

    const hash = await bcrypt.hash(password, 10);
    const newUser = new User({ username, email, password: hash });
    await newUser.save();

    res.status(201).json({ message: "Регистрация успешна" });
  } catch (err) {
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

app.get("/users", async(req, res) =>{
  try{
    const users = await User.find({}, "-password");
    res.json(users);
  }catch(err){
    res.status(500).json({message: "Ошибка при получении пользователей"})
  }
});

app.get("/profile", authMiddleware, async(req, res) =>{
  try{
    const user = await User.findById(req.userId, "-password");
    if (!user) return res.status(404).json({message: "Пользователь не найден"})
    res.json(user)
  }catch(err){
    res.status(500).json({message: "Ошибка при получении данных профиля"})
  }
});

const PORT = process.env.PORT || 5000
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
