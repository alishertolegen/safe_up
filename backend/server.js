const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");

const app = express();
app.use(express.json());
app.use(cors());

mongoose.connect("mongodb+srv://admin:TTT1337@cluster0.kz8z9tt.mongodb.net/?appName=Cluster0")
  .then(() => console.log("MongoDB connected"))
  .catch(err => console.error("MongoDB connection error:", err));

const userSchema = new mongoose.Schema({
  username: String,
  email: String,
  password: String
});

const User = mongoose.model("User", userSchema);

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

    const token = jwt.sign({ id: user._id }, "secretKey123", { expiresIn: "1d" });
    res.json({ message: "Успешный вход", token });
  } catch (err) {
    res.status(500).json({ message: "Ошибка сервера" });
  }
});

app.listen(5000, () => console.log("Server running on port 5000"));
