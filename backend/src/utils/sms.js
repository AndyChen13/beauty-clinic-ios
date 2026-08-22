const tencentcloud = require('tencentcloud-sdk-nodejs-sms');
const SmsClient = tencentcloud.sms.v20210111.Client;

const client = new SmsClient({
  credential: {
    secretId: process.env.TENCENT_SECRET_ID,
    secretKey: process.env.TENCENT_SECRET_KEY,
  },
  region: 'ap-guangzhou',
  profile: {
    signMethod: 'TC3-HMAC-SHA256',
    httpProfile: {
      reqMethod: 'POST',
      reqTimeout: 30,
    },
  },
});

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function sendSmsCode(phone, code) {
  const params = {
    SmsSdkAppId: process.env.SMS_APP_ID,
    SignName: process.env.SMS_SIGN_NAME,
    TemplateId: process.env.SMS_TEMPLATE_ID,
    TemplateParamSet: [code, '5'],
    PhoneNumberSet: [`+86${phone}`],
  };

  return new Promise((resolve, reject) => {
    client.SendSms(params, (err, response) => {
      if (err) {
        console.error('SMS send error:', err);
        reject(err);
        return;
      }
      const sendStatus = response.SendStatusSet?.[0];
      if (sendStatus && sendStatus.Code === 'Ok') {
        resolve({ success: true, messageId: sendStatus.MessageId });
      } else {
        reject(new Error(sendStatus?.Message || '短信发送失败'));
      }
    });
  });
}

module.exports = {
  generateCode,
  sendSmsCode,
};
