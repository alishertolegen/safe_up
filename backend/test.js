// test.js
require('dotenv').config();
const SibApiV3Sdk = require('sib-api-v3-sdk');

const defaultClient = SibApiV3Sdk.ApiClient.instance;
const apiKey = defaultClient.authentications['api-key'];

// 🔑 ВСТАВЬ СВОЙ API КЛЮЧ
apiKey.apiKey = process.env.BREVO_API_KEY;

const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();

async function sendResetEmail() {
  try {
    const result = await apiInstance.sendTransacEmail({
      sender: {
        name: "SafeUpProduction",
        email: "alishertolegen1337@gmail.com" // ⚠ должен быть подтверждён в Brevo
      },
      to: [
        {
          email: "alisher1337t@yahoo.com", // сюда придёт письмо
          name: "Test User"
        }
      ],
      subject: "Сброс пароля 🔐",
      htmlContent: `
        <h2>Сброс пароля</h2>
        <p>Вы запросили сброс пароля.</p>
        <a href="http://localhost:3000/reset-password?token=123456">
          Нажмите сюда для сброса
        </a>
      `
    });

    console.log("Письмо отправлено:", result);
  } catch (error) {
    console.error("Ошибка отправки:", error.response?.body || error);
  }
}

sendResetEmail();
