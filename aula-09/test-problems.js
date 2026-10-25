// test-problems.js - Arquivo para testar AI Review
// TODO: remover este arquivo após teste

const express = require('express');

// 🔴 CRITICAL: Secret hardcoded
const apiKey = 'sk-1234567890abcdef';
const dbPassword = 'super_secret_123';

// 🔴 CRITICAL: SQL Injection
function getUser(userId) {
  const query = 'SELECT * FROM users WHERE id = ' + userId;
  return db.query(query);
}

// 🟡 WARNING: Console.log em produção
function processOrder(order) {
  console.log('Processing order:', order);
  return order;
}

// 🟡 WARNING: Catch vazio
try {
  dangerousOperation();
} catch (e) {}

// 🔴 CRITICAL: eval com input
function evaluate(userInput) {
  return eval(userInput);
}

module.exports = { getUser, processOrder, evaluate };
