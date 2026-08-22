# Cidade em Construção — O Futuro do Morar
### Sandbox urbano de pesquisa de produto imobiliário · ENEDES / Lab Consumer

Jogo web 3D (voxel/estilizado) em que o participante projeta um empreendimento imobiliário
sob orçamento. Cada decisão vira **dado de pesquisa**. Esta versão inclui **login/senha**,
**perfil sociodemográfico** e **persistência no Supabase**.

> Arte, blocos e interface são autorais. Sem uso de marcas ou elementos proprietários de terceiros.
> Os "participantes" da camada social do jogo são **simulados** até o multiplayer real ser ligado.

---

## Estrutura do repositório

```
cidade-em-construcao/
├── index.html            # o jogo (com portão de login + gravação no Supabase)
├── login.html            # login/cadastro + formulário sociodemográfico (LGPD)
├── js/
│   ├── config.js         # URL + chave pública do Supabase
│   ├── supabase.js       # cliente Supabase + helpers (auth/perfil/sessões/eventos)
│   └── vendor/           # Three.js embutido localmente (sem depender de CDN)
│       ├── three.module.js
│       └── addons/controls/OrbitControls.js
├── supabase/
│   └── schema.sql        # tabelas + RLS (rode no SQL Editor do Supabase)
├── .gitignore
└── README.md
```

Sem build/bundler: são arquivos estáticos. Requer internet (Three.js e Supabase via CDN).

---

## 1. Subir para o Git

```bash
cd cidade-em-construcao
git init
git add .
git commit -m "MVP Cidade em Construção com Supabase"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/cidade-em-construcao.git
git push -u origin main
```

> A **anon key** do Supabase é pública e pode ir para o Git. **Nunca** versione a chave
> `service_role` (secreta). O `.gitignore` já bloqueia `.env` e `js/config.local.js`.

---

## 2. Configurar o Supabase

1. O cliente já está configurado para o projeto **BUSINESSGAME**.
2. Em **Authentication → Providers**, mantenha **Email** habilitado. Para permitir “entrar como convidado”, habilite **Anonymous sign-ins**. Em ambiente de teste, a confirmação de e-mail pode ser desligada em **Authentication → Sign In / Providers → Email**.
3. Em **Authentication → URL Configuration**, adicione a URL publicada em *Site URL* e *Redirect URLs*.
4. Se for apontar o jogo para outro projeto, atualize `js/config.js` apenas com a URL e uma chave pública:
   ```js
   window.SUPABASE_CONFIG = {
     url: 'https://SEU-PROJETO.supabase.co',
     anonKey: 'SUA-CHAVE-PUBLICA'
   };
   ```
5. Nunca use a chave `service_role` em arquivos do navegador.

O arquivo raiz `index.html` encaminha automaticamente para o jogo em `cidade-em-construcao/login.html`, permitindo publicar o repositório inteiro em uma hospedagem estática.

---

## 3. Publicar (deploy)

**GitHub Pages:** Settings → Pages → Branch `main` / pasta `/root`. O jogo abre em `.../index.html`
(que redireciona para `login.html` quando o Supabase está configurado).

**Vercel / Netlify:** importe o repositório; framework “None/Static”; publique a raiz.

> Não abra por `file://` — o login (localStorage) e os módulos ES podem ser bloqueados.
> Use um servidor: `python3 -m http.server 8000` e acesse `http://localhost:8000/`.

---

## 4. Fluxo de dados

- **login.html** autentica (e-mail/senha ou convidado anônimo) e coleta o **perfil sociodemográfico**
  (tabela `perfil`), com consentimento **LGPD**.
- **index.html** exige sessão válida + perfil; ao concluir a partida, grava um registro em
  `sessoes` (resumo) e o log completo em `eventos`.
- **RLS** garante que cada participante só acessa os próprios dados. A **análise agregada** é feita
  pela pesquisadora no SQL Editor do Supabase (ou via `service_role` no back-end) — nunca exposta ao participante.

### Tabelas
- `perfil` — dados sociodemográficos por usuário (faixa etária, gênero, escolaridade, renda, composição familiar, UF, moradia, finalidade, interesse em sustentabilidade, consentimento LGPD).
- `sessoes` — um registro por partida concluída, com o `resumo` (JSON) da sessão.
- `eventos` — log de interações (`item_added`, `likert`, `param_set`, `role_chosen`, `peer_shown`, …) em JSON.

### Exemplo de consulta agregada (SQL Editor)
```sql
-- atributos mais escolhidos
select payload->>'id' as atributo, count(*) as n
from public.eventos
where tipo='item_added' and payload->>'kind'='atributo'
group by 1 order by n desc;

-- metragem média declarada por papel
select resumo->>'papel' as papel, avg((resumo->>'metragem_m2')::numeric) as m2_medio
from public.sessoes group by 1;
```

---

## 5. Próximos passos sugeridos
- **Multiplayer real** (Supabase Realtime) substituindo os participantes simulados.
- **Painel do gestor** lendo agregados via view `security definer` ou função RPC (sem expor linhas individuais).
- **Modelos `.glb/.gltf`** (GLTFLoader) para itens foto-realistas.

---

## 6. Limitações honestas
- A camada social usa participantes **simulados** (constante `PEERS` em `index.html`).
- O painel de insights do jogo usa um **dataset de exemplo** + a sessão atual; a análise real vem do Supabase.
- Requer **internet** (Supabase via CDN). O **Three.js já vem embutido** em `js/vendor/` (não depende de CDN para a cena 3D) — importante em redes institucionais que bloqueiam CDNs.
- Se a tela abrir **em branco**: rode via servidor (não `file://`), confirme que a pasta `js/vendor/` foi publicada, e veja o **Console (F12)**. Um aviso de diagnóstico aparece automaticamente após alguns segundos se a cena não iniciar.
- A conexão com o Supabase **não foi testada em produção** neste pacote — siga os passos 2–3 e valide no seu projeto.
