import * as esbuild from 'esbuild';

const options = {
  entryPoints: ['js/app.tsx', 'css/app.css'],
  outdir: '../priv/static/assets',
  entryNames: '[name]',
  bundle: true,
  format: 'esm',
  target: 'es2022',
  jsx: 'automatic',
  minify: !process.argv.includes('--watch'),
  define: { 'process.env.NODE_ENV': JSON.stringify(process.argv.includes('--watch') ? 'development' : 'production') },
};

if (process.argv.includes('--watch')) {
  const context = await esbuild.context(options);
  await context.watch();
} else {
  await esbuild.build(options);
}
