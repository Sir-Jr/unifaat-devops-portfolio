// ============================================
// AI Code Review - TechNova (Aula 09)
// ============================================
// Analisa o diff de um Pull Request e gera um relatório em Markdown.
//
// O Learner Lab não tem Bedrock, então a análise é baseada em regras
// (pattern matching). A função analyzeDiff() é o ponto onde, num ambiente
// com acesso a um modelo, o diff seria enviado para a IA.
//
// Entradas (variáveis de ambiente):
//   DIFF_FILE    caminho do diff do PR       (padrão: /tmp/pr-diff.txt)
//   REPORT_FILE  onde gravar o relatório     (padrão: /tmp/ai-review-result.md)
//   GITHUB_OUTPUT  definido pelo Actions; recebe critical/warning/info/total
//
// Saída: o script não falha por achados. O bloqueio (quality gate) é um
// step separado do workflow, para o comentário ser postado mesmo com CRITICAL.
// Só sai com código 2 se a própria análise quebrar.

const fs = require('fs');

const MARKER = '<!-- ai-review-technova -->';

const SEVERITY = {
  CRITICAL: '🔴 CRITICAL',
  WARNING: '🟡 WARNING',
  INFO: '🔵 INFO'
};

// Arquivos que não são analisados: documentação e os próprios arquivos de
// regras (eles contêm os padrões procurados e gerariam falso positivo).
const IGNORED_FILES = [
  /\.md$/i,
  /(^|\/)package-lock\.json$/,
  /^\.github\/scripts\/ai-review\.js$/,
  /^\.github\/workflows\/security-scan\.yml$/
];

// Valores que parecem segredo mas são referências seguras: secrets do
// Actions, variáveis de ambiente, placeholders e valores de configuração
// (ex.: http_tokens = "required" no Terraform da EC2).
const SAFE_SECRET_VALUE = /\$\{\{|process\.env|^<.*>$|^\*+$|^(change[_-]?me|example|xxx+|your[_-].*|required|optional|true|false|null|none)$/i;

// files: limita a regra a certos tipos de arquivo (padrão: todos)
const RULES = [
  // ---------- CRITICAL (bloqueiam o PR) ----------
  {
    id: 'hardcoded-secret',
    pattern: /\b\w*(password|passwd|pwd|secret|api[_-]?key|apikey|token|access[_-]?key)\w*\s*[:=]\s*['"]([^'"]{4,})['"]/i,
    message: 'Possível secret/credencial hardcoded',
    severity: SEVERITY.CRITICAL,
    // ignora valores que são referências seguras
    accept: (m) => !SAFE_SECRET_VALUE.test(m[2])
  },
  {
    id: 'aws-access-key',
    pattern: /\b(AKIA|ASIA)[0-9A-Z]{16}\b/,
    message: 'Chave de acesso AWS no código',
    severity: SEVERITY.CRITICAL
  },
  {
    id: 'private-key',
    pattern: /-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/,
    message: 'Chave privada no código',
    severity: SEVERITY.CRITICAL
  },
  {
    id: 'eval',
    pattern: /\beval\s*\(/,
    message: 'Uso de eval() - risco de code injection',
    severity: SEVERITY.CRITICAL,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'new-function',
    pattern: /\bnew\s+Function\s*\(/,
    message: 'new Function() executa string como código (equivale a eval)',
    severity: SEVERITY.CRITICAL,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'command-injection',
    pattern: /\b(exec|execSync|spawn)\s*\(\s*(`[^`]*\$\{|['"][^'"]*['"]\s*\+)/,
    message: 'Possível command injection (comando montado com variável)',
    severity: SEVERITY.CRITICAL,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'sql-injection',
    pattern: /\b(SELECT|INSERT|UPDATE|DELETE)\b[^'"`]*\b(FROM|INTO|SET|WHERE)\b.*(['"`]\s*\+|\$\{)/i,
    message: 'Possível SQL injection - use queries parametrizadas',
    severity: SEVERITY.CRITICAL,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'tls-disabled',
    pattern: /rejectUnauthorized\s*:\s*false|NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*['"]?0/,
    message: 'Verificação de certificado TLS desativada',
    severity: SEVERITY.CRITICAL
  },

  // ---------- WARNING (informam, não bloqueiam) ----------
  {
    id: 'console-log',
    pattern: /\bconsole\.(log|debug|info)\s*\(/,
    message: 'console.log em código de produção (remover ou usar logger)',
    severity: SEVERITY.WARNING,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'empty-catch',
    pattern: /catch\s*(\(\s*\w*\s*\))?\s*\{\s*\}/,
    message: 'Catch vazio - erros silenciados podem esconder bugs',
    severity: SEVERITY.WARNING,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'debugger',
    pattern: /^\s*debugger\s*;?\s*$/,
    message: 'Instrução debugger esquecida',
    severity: SEVERITY.WARNING,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'bind-all',
    pattern: /['"]0\.0\.0\.0['"]|INADDR_ANY/,
    message: 'Binding em 0.0.0.0 - verificar se é intencional',
    severity: SEVERITY.WARNING
  },
  {
    id: 'cors-open',
    pattern: /origin\s*:\s*['"]\*['"]|Access-Control-Allow-Origin['"]?\s*,\s*['"]\*['"]/,
    message: 'CORS liberado para qualquer origem',
    severity: SEVERITY.WARNING
  },
  {
    id: 'docker-latest',
    pattern: /^\s*FROM\s+\S+:latest\b/i,
    message: 'FROM com tag :latest - build não reproduzível',
    severity: SEVERITY.WARNING,
    files: /(^|\/)Dockerfile[^/]*$/
  },
  {
    id: 'docker-root',
    pattern: /^\s*USER\s+(root|0)\s*$/i,
    message: 'Container configurado para rodar como root',
    severity: SEVERITY.WARNING,
    files: /(^|\/)Dockerfile[^/]*$/
  },

  // ---------- INFO (sugestões) ----------
  {
    id: 'todo',
    pattern: /\b(TODO|FIXME|HACK|XXX)\b/,
    message: 'Comentário TODO/FIXME - resolver antes do merge',
    severity: SEVERITY.INFO
  },
  {
    id: 'var',
    pattern: /^\s*var\s+\w+/,
    message: 'Uso de var - prefira const/let',
    severity: SEVERITY.INFO,
    files: /\.(js|ts|mjs|cjs)$/
  },
  {
    id: 'insecure-http',
    pattern: /['"]http:\/\/(?!localhost|127\.0\.0\.1|0\.0\.0\.0)[^'"]+['"]/,
    message: 'URL http:// sem TLS',
    severity: SEVERITY.INFO
  }
];

// Percorre o diff unificado e devolve os achados nas linhas ADICIONADAS,
// com o número real da linha no arquivo novo (lido do cabeçalho @@ do hunk).
function analyzeDiff(diffContent) {
  const findings = [];
  const lines = diffContent.split('\n');
  let currentFile = null;
  let newLine = 0;

  for (const line of lines) {
    if (line.startsWith('diff --git')) {
      currentFile = null;
      continue;
    }
    if (line.startsWith('+++ ')) {
      const target = line.substring(4).trim();
      currentFile = target === '/dev/null' ? null : target.replace(/^b\//, '');
      continue;
    }
    if (line.startsWith('--- ')) {
      continue;
    }
    const hunk = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (hunk) {
      newLine = parseInt(hunk[1], 10);
      continue;
    }
    if (!currentFile) {
      continue;
    }

    if (line.startsWith('+')) {
      if (!IGNORED_FILES.some((re) => re.test(currentFile))) {
        const code = line.substring(1);
        for (const rule of RULES) {
          if (rule.files && !rule.files.test(currentFile)) {
            continue;
          }
          const match = code.match(rule.pattern);
          if (match && (!rule.accept || rule.accept(match))) {
            findings.push({
              rule: rule.id,
              file: currentFile,
              line: newLine,
              code: code.trim(),
              message: rule.message,
              severity: rule.severity
            });
          }
        }
      }
      newLine++;
    } else if (line.startsWith(' ')) {
      newLine++;
    }
    // linhas removidas ('-') não avançam a numeração do arquivo novo
  }

  return findings;
}

// Escapa texto para caber numa célula de tabela Markdown dentro de `code`
function cell(text, max) {
  let t = text.length > max ? text.substring(0, max - 3) + '...' : text;
  t = t.replace(/\|/g, '\\|').replace(/`/g, '\'');
  return t;
}

function generateReport(findings, meta = {}) {
  const header = `${MARKER}\n## 🤖 AI Code Review - TechNova\n\n`;
  const footer = '\n---\n' +
    `*Review automatizado (análise por regras, ${RULES.length} padrões)` +
    (meta.sha ? ` · commit \`${meta.sha.substring(0, 7)}\`` : '') + '*\n' +
    '*⚠️ Falsos positivos são possíveis. Avalie cada achado criticamente — ' +
    'este review complementa, mas não substitui, o review humano.*\n';

  if (findings.length === 0) {
    return header +
      '✅ **Nenhum problema encontrado!**\n\n' +
      'O código alterado neste PR passou pela análise automatizada sem achados.\n' +
      footer;
  }

  const order = [SEVERITY.CRITICAL, SEVERITY.WARNING, SEVERITY.INFO];
  const count = (s) => findings.filter((f) => f.severity === s).length;
  const sorted = [...findings].sort(
    (a, b) => order.indexOf(a.severity) - order.indexOf(b.severity)
  );

  let report = header;
  report += `**Resumo:** ${findings.length} achado(s)\n\n`;
  report += '| Severidade | Quantidade | Ação |\n|:--|:--:|:--|\n';
  report += `| ${SEVERITY.CRITICAL} | ${count(SEVERITY.CRITICAL)} | bloqueia o merge |\n`;
  report += `| ${SEVERITY.WARNING} | ${count(SEVERITY.WARNING)} | recomendado corrigir |\n`;
  report += `| ${SEVERITY.INFO} | ${count(SEVERITY.INFO)} | sugestão |\n\n`;

  if (count(SEVERITY.CRITICAL) > 0) {
    report += '> ⛔ **Quality gate: este PR tem achados CRITICAL e está bloqueado até a correção.**\n\n';
  } else {
    report += '> ✅ **Quality gate: sem achados CRITICAL — o PR pode seguir para o review humano.**\n\n';
  }

  report += '### Achados detalhados\n\n';
  report += '| Severidade | Arquivo | Linha | Problema | Código |\n';
  report += '|:----------:|---------|:-----:|----------|--------|\n';
  for (const f of sorted) {
    report += `| ${f.severity} | \`${cell(f.file, 45)}\` | ${f.line} | ${f.message} | \`${cell(f.code, 50)}\` |\n`;
  }

  return report + footer;
}

function summarize(findings) {
  return {
    critical: findings.filter((f) => f.severity === SEVERITY.CRITICAL).length,
    warning: findings.filter((f) => f.severity === SEVERITY.WARNING).length,
    info: findings.filter((f) => f.severity === SEVERITY.INFO).length,
    total: findings.length
  };
}

function main() {
  const diffFile = process.env.DIFF_FILE || '/tmp/pr-diff.txt';
  const reportFile = process.env.REPORT_FILE || '/tmp/ai-review-result.md';

  try {
    const diffContent = fs.readFileSync(diffFile, 'utf8');
    const findings = analyzeDiff(diffContent);
    const report = generateReport(findings, { sha: process.env.HEAD_SHA });
    const summary = summarize(findings);

    fs.writeFileSync(reportFile, report);
    if (process.env.GITHUB_OUTPUT) {
      const out = Object.entries(summary).map(([k, v]) => `${k}=${v}`).join('\n');
      fs.appendFileSync(process.env.GITHUB_OUTPUT, out + '\n');
    }

    console.log(report);
    console.log(`\nAnálise completa: ${summary.total} achado(s) — ` +
      `CRITICAL ${summary.critical}, WARNING ${summary.warning}, INFO ${summary.info}`);
  } catch (error) {
    console.error('Erro na análise:', error.message);
    fs.writeFileSync(reportFile,
      `${MARKER}\n## 🤖 AI Code Review - TechNova\n\n⚠️ Erro durante a análise: ${error.message}\n`);
    process.exit(2);
  }
}

if (require.main === module) {
  main();
}

module.exports = { analyzeDiff, generateReport, summarize, RULES, SEVERITY, MARKER };
