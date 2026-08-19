const fs = require('node:fs');
const path = require('node:path');
const luaparse = require('luaparse');

function visit(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? visit(file) : entry.name.endsWith('.lua') ? [file] : [];
  });
}

const files = [...visit('apps'), ...visit('tests')];
for (const file of files) {
  luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
  console.log(`ok ${file}`);
}
