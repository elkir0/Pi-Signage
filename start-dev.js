const { spawn } = require('child_process');
const path = require('path');

// Change to the script's directory
process.chdir(path.dirname(__filename));

// Start Next.js in production mode on port 80
const next = spawn('npm', ['run', 'start'], {
  env: { ...process.env, PORT: '80' },
  stdio: 'inherit',
  shell: true
});

next.on('error', (err) => {
  console.error('Failed to start Next.js:', err);
  process.exit(1);
});

next.on('exit', (code) => {
  console.log(`Next.js exited with code ${code}`);
  process.exit(code);
});