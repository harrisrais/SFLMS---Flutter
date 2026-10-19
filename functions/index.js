const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.sendNotificationPush = onDocumentCreated('notifications/{notificationId}', async (event) => {
  const notification = event.data?.data();
  if (!notification?.userId) return;

  const tokenSnapshot = await db.collection('fcmTokens')
    .where('userId', '==', notification.userId)
    .get();
  const tokens = tokenSnapshot.docs.map((doc) => doc.id).filter(Boolean);
  if (!tokens.length) return;

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: notification.title || 'SFLMS update',
      body: notification.body || 'Your shipment has an update.',
    },
    data: {
      type: String(notification.type || 'info'),
      requestId: String(notification.requestId || ''),
    },
    webpush: {
      fcmOptions: { link: '/' },
    },
  });

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (!result.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(result.error?.code)) {
      invalidTokens.push(tokens[index]);
    }
  });
  await Promise.all(invalidTokens.map((token) => db.collection('fcmTokens').doc(token).delete()));
  logger.info('Notification push sent', { notificationId: event.params.notificationId, successCount: response.successCount });
});

exports.processPaymentReminders = onSchedule('every 1 hours', async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await db.collection('shipmentRequests').where('status', '==', 'approved').get();
  const reminderWindow = new Date(Date.now() + 6 * 60 * 60 * 1000);
  const writes = [];

  for (const doc of snapshot.docs) {
    const request = doc.data();
    const dueAt = request.commitmentFeeDueAt?.toDate?.();
    if (request.commitmentFeeStatus !== 'unpaid' || !dueAt || request.paymentReminderSentAt || dueAt <= now.toDate()) continue;
    if (dueAt > reminderWindow) continue;
    writes.push(db.collection('notifications').add({
      userId: request.customerId,
      title: 'Payment reminder',
      body: `Your commitment fee for ${request.pickupCity} to ${request.destinationCity} is due soon.`,
      type: 'payment_reminder',
      requestId: doc.id,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
    writes.push(doc.ref.update({ paymentReminderSentAt: admin.firestore.FieldValue.serverTimestamp() }));
  }

  await Promise.all(writes);
});

exports.expireUnpaidBookings = onSchedule('every 1 hours', async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await db.collection('shipmentRequests').where('status', '==', 'approved').get();
  const writes = [];
  for (const doc of snapshot.docs) {
    const request = doc.data();
    const dueAt = request.commitmentFeeDueAt?.toDate?.();
    if (request.commitmentFeeStatus !== 'unpaid' || !dueAt || dueAt > now.toDate()) continue;
    writes.push(doc.ref.update({
      status: 'cancelled',
      commitmentFeeStatus: 'expired',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: 'Commitment fee not paid within 24 hours.',
    }));
    writes.push(db.collection('notifications').add({
      userId: request.customerId,
      title: 'Booking auto-cancelled',
      body: `Your ${request.pickupCity} to ${request.destinationCity} booking was cancelled because the commitment fee was not paid within 24 hours.`,
      type: 'cancelled',
      requestId: doc.id,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
  }
  await Promise.all(writes);
});
