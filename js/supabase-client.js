import { createClient } from '@supabase/supabase-js';
import { AIDA_SUPABASE_CONFIG } from './supabase-config.js';

const { url, publishableKey } = AIDA_SUPABASE_CONFIG;
const isConfigured = url
    && publishableKey
    && !url.includes('PEGA_AQUI')
    && !publishableKey.includes('PEGA_AQUI');

if (!isConfigured) {
    console.warn('Completa js/supabase-config.js para conectar AIDA con Supabase.');
} else {
    window.aidaSupabase = createClient(url, publishableKey);
}