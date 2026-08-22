// ============================================================
// Cliente Supabase + helpers (auth, perfil, sessões, eventos)
// Carregado como ES module. Requer window.SUPABASE_CONFIG (js/config.js).
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cfg = window.SUPABASE_CONFIG || {};
export const isConfigured =
  !!cfg.url && !cfg.url.includes('SEU-PROJETO') &&
  !!cfg.anonKey && !cfg.anonKey.includes('SUA-ANON');

export const supabase = isConfigured ? createClient(cfg.url, cfg.anonKey) : null;

// ---- Autenticação ----
export async function getSession(){
  if(!supabase) return null;
  const { data } = await supabase.auth.getSession();
  return data.session;
}
export function signUp(email, password){
  return supabase.auth.signUp({ email, password });
}
export function signIn(email, password){
  return supabase.auth.signInWithPassword({ email, password });
}
export function signInAnon(){
  // Requer "Anonymous sign-ins" habilitado em Authentication → Providers.
  return supabase.auth.signInAnonymously();
}
export function resetPassword(email){
  return supabase.auth.resetPasswordForEmail(email, { redirectTo: new URL('login.html', location.href).href });
}
export function signOut(){
  return supabase.auth.signOut();
}

// ---- Perfil sociodemográfico ----
export async function getProfile(uid){
  if(!supabase) return null;
  const { data } = await supabase.from('perfil').select('*').eq('user_id', uid).maybeSingle();
  return data;
}
export function saveProfile(uid, fields){
  return supabase.from('perfil').upsert({
    user_id: uid, ...fields, atualizado_em: new Date().toISOString()
  });
}

export function touchProfile(uid, fields = {}){
  return supabase.from('perfil').update({
    ...fields,
    ultima_atividade_em: new Date().toISOString(),
    atualizado_em: new Date().toISOString()
  }).eq('user_id', uid);
}

export async function getTeacher(){
  if(!supabase) return null;
  const { data:{ session } } = await supabase.auth.getSession();
  if(!session?.user?.email) return null;
  const { data, error } = await supabase.from('docentes')
    .select('email,turma_codigo,nome_exibicao')
    .eq('email', session.user.email.toLowerCase())
    .maybeSingle();
  if(error) throw error;
  return data;
}

export async function getClassDashboard(turmaCodigo){
  if(!supabase) throw new Error('Supabase não configurado.');
  const { data, error } = await supabase.rpc('dashboard_turma', { p_codigo_turma: turmaCodigo });
  if(error) throw error;
  return data;
}

// ---- Sessão de jogo + eventos ----
export async function saveSession(resumo, eventos){
  if(!supabase) return null;
  const { data:{ session } } = await supabase.auth.getSession();
  if(!session) return null;
  const uid = session.user.id;

  const { data: sess, error } = await supabase
    .from('sessoes').insert({ user_id: uid, resumo }).select('id').single();
  if(error) throw error;

  if(eventos && eventos.length){
    const rows = eventos.map(e => {
      const { t, type, ...payload } = e;
      return { sessao_id: sess.id, user_id: uid, tipo: type, payload, criado_em: new Date(t).toISOString() };
    });
    // insere em lotes de 500 para não estourar o limite de payload
    for(let i=0;i<rows.length;i+=500){
      const { error: e2 } = await supabase.from('eventos').insert(rows.slice(i,i+500));
      if(e2) throw e2;
    }
  }
  return sess.id;
}
