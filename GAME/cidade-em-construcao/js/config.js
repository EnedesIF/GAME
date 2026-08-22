// ============================================================
// Configuração do Supabase
// Painel do Supabase → Project Settings → API
//  - "Project URL"  -> url
//  - "Publishable key"  -> anonKey  (esta chave é PÚBLICA, pode ir para o Git)
//
// NUNCA coloque aqui a chave "service_role" (secreta). Ela nunca vai para o front-end nem para o Git.
// Enquanto estiver com os placeholders abaixo, o jogo roda em MODO LOCAL (sem login/persistência).
// ============================================================
window.SUPABASE_CONFIG = {
  url: 'https://kzqcfrsibhzpdloehhwj.supabase.co',
  anonKey: 'sb_publishable_HwAMu39YMrvO3-4_k7Olfg_LrtTTILv'
};
