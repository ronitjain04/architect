// Small-beta operations. Requires GOOGLE_APPLICATION_CREDENTIALS or ADC.
// Read-only by default; --apply is required for every mutation.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

const projectId = 'architect-31445';
initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const auth = getAuth();
const [command, id, flag] = process.argv.slice(2);
const apply = flag === '--apply';

async function eraseTree(ref) {
  for (const collection of await ref.listCollections()) {
    for (const doc of (await collection.get()).docs) await eraseTree(doc.ref);
  }
  await ref.delete();
}

async function removePost(postID) {
  const postRef = db.collection('posts').doc(postID);
  const post = await postRef.get();
  if (!post.exists) return;
  console.log(`Post ${postID}: ${post.get('title')} by ${post.get('authorUid')}`);
  if (!apply) return;
  await eraseTree(postRef);
  for (const user of (await db.collection('users').get()).docs) {
    if ((user.get('savedPosts') || []).includes(postID)) {
      await user.ref.update({ savedPosts: FieldValue.arrayRemove(postID) });
    }
    for (const notice of (await user.ref.collection('notifications').get()).docs) {
      if (notice.get('postID') === postID) await notice.ref.delete();
    }
  }
}

async function deleteAccount(uid) {
  const requestRef = db.collection('deletionRequests').doc(uid);
  const request = await requestRef.get();
  if (!request.exists || request.get('status') !== 'pending') {
    throw new Error('A pending in-app deletion request is required.');
  }
  const profileRef = db.collection('users').doc(uid);
  const profile = await profileRef.get();
  const username = profile.get('username');
  console.log(`Deletion request: ${uid}, username: ${username || '(none)'}`);
  if (!apply) return;

  // Remove authored content and its nested room/comment documents first.
  for (const post of (await db.collection('posts').where('authorUid', '==', uid).get()).docs) {
    await removePost(post.id);
  }
  for (const post of (await db.collection('posts').get()).docs) {
    const likes = post.get('likedBy') || [];
    if (likes.includes(uid)) await post.ref.update({ likedBy: FieldValue.arrayRemove(uid) });
    const comments = (await post.ref.collection('comments').get()).docs;
    let removedComments = 0;
    for (const comment of comments) {
      if (comment.get('authorUid') === uid) {
        await comment.ref.delete();
        removedComments += 1;
      }
    }
    if (removedComments) await post.ref.update({ commentCount: comments.length - removedComments });
  }
  for (const user of (await db.collection('users').get()).docs) {
    if (user.id === uid) continue;
    const updates = {};
    if ((user.get('following') || []).includes(username)) updates.following = FieldValue.arrayRemove(username);
    if ((user.get('blockedUIDs') || []).includes(uid)) updates.blockedUIDs = FieldValue.arrayRemove(uid);
    if (Object.keys(updates).length) await user.ref.update(updates);
    for (const notice of (await user.ref.collection('notifications').get()).docs) {
      if (notice.get('actorUid') === uid) await notice.ref.delete();
    }
  }
  for (const report of (await db.collection('reports').get()).docs) {
    if (report.get('reporterUid') === uid || report.get('authorUid') === uid) await report.ref.delete();
  }
  if (profile.exists) await eraseTree(profileRef);
  if (username) {
    const nameRef = db.collection('usernames').doc(username);
    if ((await nameRef.get()).get('uid') === uid) await nameRef.delete();
  }
  try { await auth.deleteUser(uid); }
  catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
  await requestRef.delete();
  console.log(`Deleted account ${uid}`);
}

switch (command) {
  case 'queue': {
    const reports = (await db.collection('reports').get()).docs.filter(doc => doc.get('status') !== 'resolved');
    const requests = (await db.collection('deletionRequests').where('status', '==', 'pending').get()).docs;
    console.log(JSON.stringify({
      reports: reports.map(doc => ({ id: doc.id, ...doc.data() })),
      deletionRequests: requests.map(doc => ({ id: doc.id, ...doc.data() }))
    }, null, 2));
    break;
  }
  case 'remove-post': {
    if (!id) throw new Error('Usage: node beta-ops.mjs remove-post POST_ID [--apply]');
    await removePost(id);
    break;
  }
  case 'resolve-report': {
    if (!id) throw new Error('Usage: node beta-ops.mjs resolve-report REPORT_ID [--apply]');
    const ref = db.collection('reports').doc(id);
    const report = await ref.get();
    if (!report.exists) throw new Error('Report not found');
    console.log(JSON.stringify(report.data(), null, 2));
    if (apply) await ref.update({ status: 'resolved', resolvedAt: FieldValue.serverTimestamp() });
    break;
  }
  case 'delete-account': {
    if (!id) throw new Error('Usage: node beta-ops.mjs delete-account UID [--apply]');
    await deleteAccount(id);
    break;
  }
  default: throw new Error('Usage: node beta-ops.mjs queue | remove-post ID | resolve-report ID | delete-account UID [--apply]');
}
