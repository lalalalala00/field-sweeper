// 미리 만들어 둘 판을 화면과 따로 만드는 작업자(Web Worker). common.js의 Nemo.stock이 부른다.
// 브라우저는 화면과 계산이 같은 줄에서 돌아서, 몇 초 걸리는 판을 그냥 만들면 그동안 화면이 멈춘다.
self.onmessage = e => {
  const { script, engine, level } = e.data;
  try {
    importScripts(script);
    self.postMessage({ ok: true, puzzle: self[engine].generate(level) });
  } catch (err) {
    self.postMessage({ ok: false });
  }
};
