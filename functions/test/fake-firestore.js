'use strict';

/** Minimal in-memory stand-in for the parts of Firestore payments.js uses. */
function createFakeFirestore(seed = {}) {
  const store = new Map(); // "collection/id" -> data

  for (const [path, data] of Object.entries(seed)) store.set(path, { ...data });

  function snapshot(path) {
    const data = store.get(path);
    return {
      exists: data !== undefined,
      data: () => (data === undefined ? undefined : { ...data }),
      get: (field) => (data === undefined ? undefined : data[field]),
    };
  }

  function docRef(collection, id) {
    const path = `${collection}/${id}`;
    return {
      path,
      async get() {
        return snapshot(path);
      },
      async set(data) {
        store.set(path, { ...data });
      },
      async update(data) {
        if (!store.has(path)) throw new Error(`No document to update: ${path}`);
        store.set(path, { ...store.get(path), ...data });
      },
    };
  }

  return {
    store,
    collection(name) {
      return { doc: (id) => docRef(name, id) };
    },
    async runTransaction(fn) {
      const writes = [];
      const t = {
        get: async (ref) => snapshot(ref.path),
        set: (ref, data) => writes.push(() => store.set(ref.path, { ...data })),
        update: (ref, data) =>
          writes.push(() => {
            if (!store.has(ref.path)) throw new Error(`No document to update: ${ref.path}`);
            store.set(ref.path, { ...store.get(ref.path), ...data });
          }),
      };
      const result = await fn(t);
      writes.forEach((w) => w());
      return result;
    },
  };
}

module.exports = { createFakeFirestore };
