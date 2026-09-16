const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const ORDER_CHAIN = [
  'pending',
  'confirmed',
  'packing',
  'ready',
  'on_the_way',
  'completed',
];

// ---------------------------------------------------------------------------
// 1. Custom claims — set role + companyId on the Firebase Auth token.
// ---------------------------------------------------------------------------
exports.setCustomClaims = functions.firestore
  .document('admins/{uid}')
  .onCreate(async (snap) => {
    const data = snap.data();
    await admin.auth().setCustomUserClaims(snap.id, {
      role: 'admin',
      companyId: data.companyId || '',
    });
  });

exports.setEmployeeClaims = functions.firestore
  .document('employees/{uid}')
  .onCreate(async (snap) => {
    const data = snap.data();
    await admin.auth().setCustomUserClaims(snap.id, {
      role: 'employee',
      companyId: data.companyId || '',
    });
  });

exports.setUserClaims = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap) => {
    await admin.auth().setCustomUserClaims(snap.id, {
      role: 'user',
      companyId: '',
    });
  });

// ---------------------------------------------------------------------------
// 2. Order state machine — validate transitions + fan out notifications.
// ---------------------------------------------------------------------------
const STATUS_MESSAGES = {
  confirmed: "Your order has been confirmed.",
  cancelled: "Your order was cancelled.",
  packing: "Your order is being packed.",
  ready: "Your order is ready for pickup.",
  on_the_way: "Your order is on the way.",
  completed: "Your order has been completed.",
};

exports.onOrderUpdate = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    const prev = before.orderStatus;
    const next = after.orderStatus;
    if (!prev || prev === next) return null;

    const prevIdx = ORDER_CHAIN.indexOf(prev);
    const nextIdx = ORDER_CHAIN.indexOf(next);
    const isForward = nextIdx === prevIdx + 1;
    const isCancel = next === 'cancelled';
    if (!isForward && !isCancel) {
      await change.after.ref.update({ orderStatus: prev });
      return null;
    }

    await db.collection('notifications').add({
      recipientId: after.userId,
      role: 'user',
      type: 'order_status',
      title: `Order ${after.id || change.after.id}`,
      body: STATUS_MESSAGES[next] || `Order status: ${next}`,
      deepLink: `ecommerce://order/${change.after.id}`,
      isRead: false,
      createdAt: new Date().toISOString(),
    });

    if (after.userId) {
      const userSnap = await db.collection('users').doc(after.userId).get();
      const tokens = (userSnap.data() && userSnap.data().fcmTokens) || [];
      if (tokens.length) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: 'Order update',
            body: STATUS_MESSAGES[next] || `Order status: ${next}`,
          },
          data: { deepLink: `ecommerce://order/${change.after.id}` },
        });
      }
    }

    if (before.paymentStatus !== after.paymentStatus && after.paymentStatus === 'done') {
      await db.collection('notifications').add({
        recipientId: after.userId,
        role: 'user',
        type: 'order_status',
        title: 'Payment received',
        body: 'We have received your payment.',
        deepLink: `ecommerce://order/${change.after.id}`,
        isRead: false,
        createdAt: new Date().toISOString(),
      });
    }

    return null;
  });

// ---------------------------------------------------------------------------
// 3. New order -> notify the company's Admins (FCM topic).
// ---------------------------------------------------------------------------
exports.onOrderCreated = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    if (data.companyId) {
      await admin.messaging().send({
        topic: `company_${data.companyId}`,
        notification: {
          title: 'New order placed',
          body: `New order from ${data.companyName || 'a customer'}`,
        },
        data: { orderId: snap.id },
      });
    }
    return null;
  });

// ---------------------------------------------------------------------------
// 4. Stock alert — warn Admins when a product drops below threshold.
// ---------------------------------------------------------------------------
exports.onProductLowStock = functions.firestore
  .document('products/{productId}')
  .onUpdate(async (change) => {
    const after = change.after.data();
    if (after && after.stockQty != null && after.stockQty < 20) {
      const admins = await db
        .collection('admins')
        .where('companyId', '==', after.companyId || '')
        .get();
      admins.forEach((doc) => {
        db.collection('notifications').add({
          recipientId: doc.id,
          role: 'admin',
          type: 'stock_alert',
          title: 'Low stock',
          body: `${after.name || 'A product'} is low on stock (${after.stockQty} left).`,
          deepLink: '',
          isRead: false,
          createdAt: new Date().toISOString(),
        });
      });
    }
    return null;
  });

// ---------------------------------------------------------------------------
// 5. Account provisioning via Admin SDK (callable).
// ---------------------------------------------------------------------------
exports.createAdminUser = functions.https.onCall(async (data, context) => {
  const caller = context.auth;
  if (!caller || !caller.token || caller.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins may create admin accounts.');
  }
  const { email, password, name, mobileNumber, address, companyId } = data;
  const companyRef = companyId || caller.token.companyId;
  const user = await admin.auth().createUser({ email, password });
  await admin.auth().setCustomUserClaims(user.uid, { role: 'admin', companyId: companyRef });
  await db.collection('admins').doc(user.uid).set({
    companyId: companyRef,
    name,
    email,
    mobileNumber: mobileNumber || '',
    address: address || '',
    gender: 'other',
    createdBy: caller.uid,
    emailVerified: false,
  });
  return { uid: user.uid };
});

exports.createEmployeeUser = functions.https.onCall(async (data, context) => {
  const caller = context.auth;
  if (!caller || !caller.token || caller.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins may create employee accounts.');
  }
  const { email, password, name, role, permissions, companyId } = data;
  const companyRef = companyId || caller.token.companyId;
  const user = await admin.auth().createUser({ email, password });
  await admin.auth().setCustomUserClaims(user.uid, { role: 'employee', companyId: companyRef });
  await db.collection('employees').doc(user.uid).set({
    companyId: companyRef,
    name,
    email,
    role: role || 'Picker',
    details: '',
    address: '',
    dob: null,
    gender: 'other',
    permissions: permissions || { canPack: true, canDispatch: false },
    shiftActive: true,
    createdBy: caller.uid,
  });
  return { uid: user.uid };
});

// ---------------------------------------------------------------------------
// 6. Voucher validation — server-side re-check at order placement (Section 9).
// ---------------------------------------------------------------------------
exports.validateVoucher = functions.https.onCall(async (data) => {
  const { voucherCode, companyId, userId, subtotal } = data;
  const snap = await db
    .collection('vouchers')
    .where('companyId', '==', companyId)
    .where('code', '==', voucherCode)
    .limit(1)
    .get();
  if (snap.empty) {
    return { valid: false, reason: 'Invalid code' };
  }
  const v = snap.docs[0].data();
  if (v.expiryDate && new Date(v.expiryDate) < new Date()) {
    return { valid: false, reason: 'Voucher expired' };
  }
  if (v.minOrderAmt && subtotal < v.minOrderAmt) {
    return { valid: false, reason: 'Minimum order amount not met' };
  }
  if ((v.usedOrderIds || []).length >= (v.maxUses || 0) && v.maxUses > 0) {
    return { valid: false, reason: 'Voucher limit reached' };
  }
  return {
    valid: true,
    discountType: v.discountType,
    discountValue: v.discountValue,
    appliesTo: v.appliesTo,
    productIds: v.productIds || [],
    categoryIds: v.categoryIds || [],
  };
});

// ---------------------------------------------------------------------------
// 7. Atomic company + initial admin provisioning (callable)
// Allows unauthenticated clients to create a new company and the first
// admin account in a single server-side operation to avoid leaving an
// orphaned company without an admin. Input validation is minimal — consider
// adding rate-limiting or captcha in production.
// ---------------------------------------------------------------------------
exports.createCompanyWithAdmin = functions.https.onCall(async (data, context) => {
  console.log('createCompanyWithAdmin invoked', { uid: context.auth && context.auth.uid, time: new Date().toISOString() });
  const company = data && data.company;
  const adminData = data && data.admin;
  if (!company || !adminData) {
    console.error('Missing company or admin data', { data });
    throw new functions.https.HttpsError('invalid-argument', 'Missing company or admin data');
  }
  if (!company.name || !company.companyPassword) {
    throw new functions.https.HttpsError('invalid-argument', 'Company name and password required');
  }
  if (!adminData.email || !adminData.password || !adminData.name) {
    throw new functions.https.HttpsError('invalid-argument', 'Admin name, email and password required');
  }

  const companyRef = db.collection('companies').doc();
  const companyId = companyRef.id;

  try {
    // Create company doc
    await companyRef.set({
      name: company.name,
      slug: company.slug || (company.name || '').toLowerCase().replace(/\s+/g, '-'),
      companyPassword: company.companyPassword,
      details: company.details || '',
      address: company.address || '',
      logoUrl: company.logoUrl || '',
      currency: company.currency || 'INR',
      deliveryTypes: company.deliveryTypes || [],
      weeklyHours: company.weeklyHours || [],
      openingDate: new Date().toISOString(),
      status: 'active',
    });

    let user = null;
    try {
      // Create Firebase Auth user for admin
      console.log('Creating auth user for admin', { email: adminData.email });
      user = await admin.auth().createUser({
        email: adminData.email,
        password: adminData.password,
        displayName: adminData.name,
      });
      console.log('Auth user created', { uid: user.uid });
    } catch (createErr) {
      console.error('Error creating auth user', createErr && createErr.stack ? createErr.stack : createErr);
      // Rollback company if user creation failed
      await companyRef.delete().catch(() => {});
      // Map common auth errors to clearer HttpsError codes
      if (createErr && createErr.code) {
        if (createErr.code === 'auth/email-already-exists') {
          throw new functions.https.HttpsError('already-exists', 'Email already in use');
        }
        if (createErr.code === 'auth/invalid-password') {
          throw new functions.https.HttpsError('invalid-argument', 'Invalid or weak password');
        }
      }
      throw new functions.https.HttpsError('internal', createErr.message || 'Failed to create auth user');
    }

    try {
      // Create admin doc
      console.log('Creating admin doc for uid', user.uid);
      await db.collection('admins').doc(user.uid).set({
        companyId: companyId,
        name: adminData.name,
        email: adminData.email,
        mobileNumber: adminData.mobileNumber || '',
        address: adminData.address || '',
        gender: adminData.gender || 'other',
        createdBy: null,
        emailVerified: false,
      });

      // Set custom claims
      await admin.auth().setCustomUserClaims(user.uid, { role: 'admin', companyId });
      console.log('Custom claims set for uid', user.uid, 'companyId', companyId);

      return { companyId, uid: user.uid };
    } catch (err) {
      console.error('Error finalizing provisioning', err && err.stack ? err.stack : err);
      // Rollback both user and company if admin doc or claims fail
      try {
        if (user && user.uid) await admin.auth().deleteUser(user.uid);
      } catch (delErr) {
        console.error('Failed to delete user during rollback', delErr);
      }
      await companyRef.delete().catch(() => {});
      throw new functions.https.HttpsError('internal', err.message || 'Provisioning failed');
    }
  } catch (err) {
    // Final catch: ensure error is an HttpsError
    console.error('Unhandled error in createCompanyWithAdmin', err && err.stack ? err.stack : err);
    if (err instanceof functions.https.HttpsError) throw err;
    const msg = err && err.message ? err.message : 'Provisioning failed';
    throw new functions.https.HttpsError('internal', msg);
  }
});

// Lightweight connectivity test for debugging from client
exports.ping = functions.https.onCall(async (data, context) => {
  console.log('ping called', { time: new Date().toISOString(), data });
  return { ok: true, time: new Date().toISOString(), echo: data || null };
});
