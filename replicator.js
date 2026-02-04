const axios = require('axios');

async function copyDb({ source, target }) {
  const success = [];
  const failure = [];

  const { data } = await axios.get(`${source}/_all_docs`);
  for (const row of data.rows) {
    try {
      const res = await axios.get(`${source}/${row.id}`);
      const doc = res.data;
      delete doc._rev;
      await axios.put(`${target}/${doc._id}`, doc);
      success.push(doc._id);
    } catch (err) {
      failure.push({ id: row.id, error: err.message });
    }
  }
  return { success, failure };
}

copyDb({
  // pas aan naar de db die je wilt kopiëren
  source: 'http://replicator:replicator_2024@couchdb2:5984/bbsid',
  target: 'http://replicator:replicator_2024@couchdb1:5984/bbsid'
})
  .then(console.log)
  .catch(console.error);
