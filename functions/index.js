const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// 毎日ランダムな時間に2回通知を送信
exports.sendDailyNotifications = functions.pubsub
  .schedule('0 0 * * *')  // 毎日 00:00 UTC に実行
  .timeZone('Asia/Tokyo')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      const today = new Date();
      const dateKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

      // ランダムな時間 2 回を生成
      const times = generateRandomTimes(2);
      console.log(`通知時刻: ${times.map(t => t.toLocaleTimeString()).join(', ')}`);

      // すべてのユーザーを取得
      const usersSnapshot = await db.collection('users').get();

      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const user = userDoc.data();

        // FCM トークンを取得
        const tokensSnapshot = await db
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .get();

        if (tokensSnapshot.empty) continue;

        const tokens = tokensSnapshot.docs.map(doc => doc.id);

        // 通知情報を初期化
        await db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(dateKey)
          .set({
            sentAt: times,
            postedAt: null,
            isOnTime: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

        // FCM 通知を送信
        const message = {
          notification: {
            title: 'OneShot 撮影時間です！',
            body: '10分以内に動画を撮影してください',
          },
          tokens: tokens,
        };

        try {
          await admin.messaging().sendMulticast(message);
          console.log(`${uid} に通知を送信しました`);
        } catch (err) {
          console.error(`${uid} への通知送信に失敗: ${err}`);
        }
      }

      return null;
    } catch (error) {
      console.error('エラー:', error);
      throw error;
    }
  });

// ランダムな時間を 2 回生成
function generateRandomTimes(count) {
  const times = [];
  const now = new Date();

  for (let i = 0; i < count; i++) {
    // 6時から22時の間でランダムな時間を生成
    const hour = Math.floor(Math.random() * 16) + 6;
    const minute = Math.floor(Math.random() * 60);

    const time = new Date(now);
    time.setHours(hour, minute, 0, 0);
    times.push(time);
  }

  return times.sort((a, b) => a - b);
}
