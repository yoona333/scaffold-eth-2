// server.js
const express = require('express');
const bodyParser = require('body-parser');
const pool = require('./db');

const app = express();

app.use(bodyParser.json());

app.get('/test', async (req, res) => {
  try {
    console.log('Received request')
    res.send("Received request")
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
  }
);

app.post('/createNFT', async (req, res) => {
  const { nftName, nftessance, nftholder, nftPrice, nftDescription, imageurl, owner, delisted } = req.body;

  if (!nftName || !nftPrice || !imageurl) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const query = `
      INSERT INTO nfts (name, essance, holder, price, description, image_url, owner, delisted)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;
    
    const values = [nftName, nftessance, nftholder, nftPrice, nftDescription, imageurl, owner, delisted];
    
    await pool.execute(query, values);
    console.log('NFT added to database successfully');
    res.status(200).json({ message: 'NFT created successfully' });
  } catch (error) {
    console.error('Error adding NFT to database:', error);
    res.status(500).json({ message: 'Error creating NFT', error });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
