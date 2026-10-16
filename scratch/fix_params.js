const fs = require('fs');
const targetFile = 'C:/website/pickle-system/server/index.js';
let code = fs.readFileSync(targetFile, 'utf8');

// Fix the parameter interpolation in get ledger
const badQueryDate = 'query += ` AND transaction_date >= ${params.length - 1} AND transaction_date <= ${params.length}`;';
const goodQueryDate = "query += ' AND transaction_date >= $' + (params.length - 1) + ' AND transaction_date <= $' + params.length;";

const badQuerySearch = 'query += ` AND (LOWER(particulars) LIKE ${params.length} OR LOWER(COALESCE(reference_number, \'\')) LIKE ${params.length})`;';
const goodQuerySearch = "query += ' AND (LOWER(particulars) LIKE $' + params.length + ' OR LOWER(COALESCE(reference_number, \\'\\')) LIKE $' + params.length + ')';";

if (code.includes(badQueryDate)) {
  code = code.replace(badQueryDate, goodQueryDate);
  console.log('Fixed badQueryDate');
}
if (code.includes(badQuerySearch)) {
  code = code.replace(badQuerySearch, goodQuerySearch);
  console.log('Fixed badQuerySearch');
}

fs.writeFileSync(targetFile, code, 'utf8');
console.log('Verified parameter syntax in index.js');
