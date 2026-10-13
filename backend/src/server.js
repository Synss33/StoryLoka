import { createApp } from './app.js';
import { env } from './config/env.js';

const app = createApp();

// `host 0.0.0.0` agar bisa diakses dari HP fisik via IP komputer.
app.listen(env.port, env.host, () => {
  console.log(
    `Storyloka API (${env.nodeEnv}) berjalan di http://localhost:${env.port}/health`,
  );
});
