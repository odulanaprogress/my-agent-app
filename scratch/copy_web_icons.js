const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', 'assets', 'logos', 'agent_logo.png');

if (!fs.existsSync(src)) {
  console.error("Source logo not found:", src);
  process.exit(1);
}

const destinations = [
  path.join(__dirname, '..', 'web', 'favicon.png'),
  path.join(__dirname, '..', 'web', 'agent_logo.png'),
  path.join(__dirname, '..', 'web', 'icons', 'Icon-192.png'),
  path.join(__dirname, '..', 'web', 'icons', 'Icon-512.png'),
  path.join(__dirname, '..', 'web', 'icons', 'Icon-maskable-192.png'),
  path.join(__dirname, '..', 'web', 'icons', 'Icon-maskable-512.png'),
  path.join(__dirname, '..', 'build', 'web', 'favicon.png'),
  path.join(__dirname, '..', 'build', 'web', 'agent_logo.png'),
  path.join(__dirname, '..', 'build', 'web', 'icons', 'Icon-192.png'),
  path.join(__dirname, '..', 'build', 'web', 'icons', 'Icon-512.png'),
  path.join(__dirname, '..', 'build', 'web', 'icons', 'Icon-maskable-192.png'),
  path.join(__dirname, '..', 'build', 'web', 'icons', 'Icon-maskable-512.png'),
];

destinations.forEach(dest => {
  const dir = path.dirname(dest);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.copyFileSync(src, dest);
  console.log(`Copied logo to ${dest}`);
});

console.log("All web icons updated with Agent logo successfully!");
