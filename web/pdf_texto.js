// Extrai o texto de um PDF no navegador com o pdf.js, que vai junto com o site
// (web/pdfjs/) e só é carregado quando alguém importa uma apostila.
// Usado para importar as perguntas das apostilas de Estudo Bíblico Indutivo.
(function () {
  const BASE = 'pdfjs/';
  let carregando = null;

  function carregar() {
    if (window.pdfjsLib) return Promise.resolve(window.pdfjsLib);
    if (!carregando) {
      carregando = new Promise(function (ok, erro) {
        const s = document.createElement('script');
        s.src = BASE + 'pdf.min.js';
        s.onload = function () {
          window.pdfjsLib.GlobalWorkerOptions.workerSrc = BASE + 'pdf.worker.min.js';
          ok(window.pdfjsLib);
        };
        s.onerror = function () { carregando = null; erro(new Error('Não foi possível carregar o leitor de PDF.')); };
        document.head.appendChild(s);
      });
    }
    return carregando;
  }

  window.pdfTexto = async function (bytes) {
    const pdfjs = await carregar();
    const doc = await pdfjs.getDocument({ data: bytes }).promise;
    let texto = '';
    for (let p = 1; p <= doc.numPages; p++) {
      const pagina = await doc.getPage(p);
      const conteudo = await pagina.getTextContent();
      for (const item of conteudo.items) {
        texto += item.str;
        if (item.hasEOL) texto += '\n';
      }
      texto += '\n\f';
    }
    return texto;
  };
})();
