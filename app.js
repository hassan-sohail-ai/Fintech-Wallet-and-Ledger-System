const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// In-memory mock database for fast prototyping (Can be replaced with PostgreSQL later)
let wallets = {
  "user_123": { balance: 1000, currency: "PKR" }
};

let ledger = [];

// Health check endpoint (Crucial for DevOps/Kubernetes liveness probes)
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', timestamp: new Date() });
});

// Get wallet balance
app.get('/wallet/:userId', (req, res) => {
  const userId = req.params.userId;
  const wallet = wallets[userId];
  if (!wallet) {
    return res.status(404).json({ error: "Wallet not found" });
  }
  res.json(wallet);
});

// Process a transaction (Credit/Debit) & maintain ledger
app.post('/transaction', (req, res) => {
  const { userId, amount, type } = req.body; // type: 'CREDIT' or 'DEBIT'
  
  if (!wallets[userId]) {
    wallets[userId] = { balance: 0, currency: "PKR" };
  }

  if (type === 'DEBIT' && wallets[userId].balance < amount) {
    return res.status(400).json({ error: "Insufficient funds" });
  }

  if (type === 'CREDIT') {
    wallets[userId].balance += Number(amount);
  } else if (type === 'DEBIT') {
    wallets[userId].balance -= Number(amount);
  } else {
    return res.status(400).json({ error: "Invalid transaction type" });
  }

  const transactionRecord = {
    id: `txn_${Date.now()}`,
    userId,
    amount,
    type,
    newBalance: wallets[userId].balance,
    timestamp: new Date()
  };

  ledger.push(transactionRecord);

  res.status(201).json({
    message: "Transaction successful",
    transaction: transactionRecord
  });
});

// Get ledger history
app.get('/ledger/:userId', (req, res) => {
  const userId = req.params.userId;
  const userTransactions = ledger.filter(txn => txn.userId === userId);
  res.json(userTransactions);
});

app.listen(PORT, () => {
  console.log(`Wallet & Ledger service running on port ${PORT}`);
});