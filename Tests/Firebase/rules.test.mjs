import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { Bytes, doc, setDoc, updateDoc, deleteDoc, arrayUnion, arrayRemove, serverTimestamp, writeBatch } from 'firebase/firestore';
let env;
before(async () => { env = await initializeTestEnvironment({ projectId: 'demo-architect', firestore: { host: '127.0.0.1', port: 8085, rules: await readFile('../../firestore.rules', 'utf8') } }); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), { username: 'alice' });
    await setDoc(doc(db, 'users/bob'), { username: 'bob' });
    await setDoc(doc(db, 'posts/room'), { authorUid: 'alice', username: 'alice', title: 'Room', description: '', likedBy: ['alice'], commentCount: 0 });
    await setDoc(doc(db, 'users/alice/notifications/like_room_bob'), { actorUid: 'bob', actorUsername: 'bob', type: 'like', postID: 'room', read: false });
  });
});
const user = uid => env.authenticatedContext(uid).firestore();
test('bob can add and remove only his own like', async () => {
  const ref = doc(user('bob'), 'posts/room');
  await assertSucceeds(updateDoc(ref, { likedBy: arrayUnion('bob') }));
  await assertSucceeds(updateDoc(ref, { likedBy: arrayRemove('bob') }));
  await assertFails(updateDoc(ref, { likedBy: [] }));
  await assertFails(updateDoc(ref, { likedBy: ['alice', 'charlie'] }));
});
test('author cannot transfer ownership', async () => {
  await assertFails(updateDoc(doc(user('alice'), 'posts/room'), { authorUid: 'bob' }));
});
test('stranger cannot delete another actors notification', async () => {
  await assertFails(deleteDoc(doc(user('charlie'), 'users/alice/notifications/like_room_bob')));
  await assertSucceeds(deleteDoc(doc(user('bob'), 'users/alice/notifications/like_room_bob')));
});
test('notification cannot impersonate another actor', async () => {
  await assertFails(setDoc(doc(user('charlie'), 'users/alice/notifications/fake'), { actorUid: 'bob', actorUsername: 'bob', type: 'like', postID: 'room', read: false, createdAt: serverTimestamp() }));
});
test('counter update must accompany a new owned comment', async () => {
  const db = user('bob');
  await assertFails(updateDoc(doc(db, 'posts/room'), { commentCount: 999 }));
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts/room/comments/comment1'), { authorUid: 'bob', publisher: 'bob', text: 'Great room', timestamp: serverTimestamp() });
  batch.update(doc(db, 'posts/room'), { commentCount: 1, lastCommentID: 'comment1' });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(db, 'posts/room'), { commentCount: 2, lastCommentID: 'comment1' }));
});
test('comment requires an existing parent post', async () => {
  await assertFails(setDoc(doc(user('bob'), 'posts/missing/comments/comment1'), { authorUid: 'bob', publisher: 'bob', text: 'Orphan', timestamp: serverTimestamp() }));
});
test('post schema limits oversized titles', async () => {
  await assertFails(setDoc(doc(user('bob'), 'posts/new'), { authorUid: 'bob', username: 'bob', title: 'x'.repeat(101), description: '', createdAt: serverTimestamp(), likedBy: [], commentCount: 0 }));
});
test('profile creation atomically reserves username and cannot steal an existing handle', async () => {
  const db = user('charlie');
  const batch = writeBatch(db);
  batch.set(doc(db, 'usernames/charlie'), { uid: 'charlie' });
  batch.set(doc(db, 'users/charlie'), { username: 'charlie', displayName: 'Charlie', bio: '', createdAt: serverTimestamp() });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(user('bob'), 'usernames/charlie'), { uid: 'bob' }));
  await assertFails(updateDoc(doc(user('charlie'), 'users/charlie'), { username: 'alice' }));
});
test('room payload can be published separately and only read when parent exists', async () => {
  const db = user('bob');
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts/shared'), { authorUid: 'bob', username: 'bob', title: 'Room', description: '', createdAt: serverTimestamp(), likedBy: [], commentCount: 0, hasScene: true });
  batch.set(doc(db, 'posts/shared/experience/scene'), { sceneData: Bytes.fromUint8Array(new Uint8Array([123,125])) });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(user('charlie'), 'posts/shared/experience/scene'), { sceneData: Bytes.fromUint8Array(new Uint8Array([1])) }));
});
test('valid like notification can be written and read-marked only by recipient', async () => {
  const db = user('bob');
  await assertSucceeds(updateDoc(doc(db,'posts/room'), { likedBy: arrayUnion('bob') }));
  await assertSucceeds(deleteDoc(doc(db, 'users/alice/notifications/like_room_bob')));
  await assertSucceeds(setDoc(doc(db, 'users/alice/notifications/like_room_bob'), { actorUid: 'bob', actorUsername: 'bob', type: 'like', postID: 'room', read: false, createdAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'users/alice/notifications/like_room_bob'), { read: true }));
  await assertSucceeds(updateDoc(doc(user('alice'), 'users/alice/notifications/like_room_bob'), { read: true }));
});
test('only signed-in reporter can file an immutable post report', async () => {
  const db = user('bob');
  await assertSucceeds(setDoc(doc(db, 'reports/report1'), { reporterUid: 'bob', postID: 'room', authorUid: 'alice', reason: 'Harassment', createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(user('charlie'), 'reports/report2'), { reporterUid: 'bob', postID: 'room', authorUid: 'alice', reason: 'Harassment', createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(user('bob'), 'reports/report3'), { reporterUid: 'bob', postID: 'missing', authorUid: 'alice', reason: 'Harassment', createdAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(db, 'reports/report1')));
});
test('only owner can add blocked users to their profile', async () => {
  await assertSucceeds(updateDoc(doc(user('bob'), 'users/bob'), { blockedUIDs: arrayUnion('alice') }));
  await assertFails(updateDoc(doc(user('alice'), 'users/bob'), { blockedUIDs: arrayUnion('alice') }));
});
test('account owner can request deletion but no other user can modify request', async () => {
  await assertSucceeds(setDoc(doc(user('bob'), 'deletionRequests/bob'), { uid: 'bob', status: 'pending', createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(user('alice'), 'deletionRequests/bob'), { uid: 'bob', status: 'pending', createdAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(user('bob'), 'deletionRequests/bob'), { status: 'cancelled' }));
});
