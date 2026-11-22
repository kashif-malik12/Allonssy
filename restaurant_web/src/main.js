import { supabase } from './supabase.js';
import { renderMenuView } from './menu_view.js';
import { renderPosView } from './pos_view.js';

async function initApp() {
  const appContainer = document.getElementById('app');

  // 1. Resolve store slug from URL / Subdomain
  const urlParams = new URLSearchParams(window.location.search);
  let slug = urlParams.get('store');

  if (!slug) {
    const host = window.location.hostname;
    // e.g. "royalfood.allonssy.com" or "royalfood.localhost"
    const parts = host.split('.');
    if (parts.length >= 3 && parts[0] !== 'www' && parts[0] !== 'app' && parts[0] !== 'supabase') {
      slug = parts[0].toLowerCase();
    } else {
      // Default fallback store for preview
      slug = 'royalfood';
    }
  }

  try {
    // 2. Fetch Store Details
    const { data: store, error: storeError } = await supabase
      .from('restaurant_stores')
      .select('*')
      .eq('slug', slug)
      .eq('is_active', true)
      .single();

    if (storeError || !store) {
      appContainer.innerHTML = `
        <div class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="w-16 h-16 bg-red-100 text-red-600 rounded-full flex items-center justify-center mb-4 text-2xl font-bold">!</div>
          <h2 class="text-xl font-bold text-slate-800">Restaurant Introuvable</h2>
          <p class="text-sm text-slate-500 max-w-sm mt-1">Le restaurant associé à l'adresse <strong>"${slug}"</strong> n'existe pas ou n'est pas encore activé.</p>
          <a href="https://allonssy.com" class="mt-4 inline-block text-xs font-bold text-orange-600 hover:underline">← Découvrir Allonssy</a>
        </div>
      `;
      return;
    }

    // Set page title & favicon
    document.title = `${store.name} | Menu & Commande en ligne`;

    // 3. Fetch Categories
    const { data: categories, error: catError } = await supabase
      .from('restaurant_categories')
      .select('*')
      .eq('store_id', store.id)
      .eq('is_active', true)
      .order('sort_order', { ascending: true });

    if (catError) throw catError;

    // 4. Fetch Items
    const { data: items, error: itemError } = await supabase
      .from('restaurant_items')
      .select('*')
      .eq('store_id', store.id)
      .eq('is_available', true)
      .order('sort_order', { ascending: true });

    if (itemError) throw itemError;

    // 5. Router (Menu vs POS)
    function route() {
      const hash = window.location.hash;
      const path = window.location.pathname;

      if (hash === '#pos' || path.endsWith('/pos')) {
        renderPosView(appContainer, store, categories || [], items || []);
      } else {
        renderMenuView(appContainer, store, categories || [], items || []);
      }
    }

    window.addEventListener('hashchange', route);
    route();

  } catch (err) {
    console.error('App init failed:', err);
    appContainer.innerHTML = `
      <div class="flex-1 flex flex-col items-center justify-center p-6 text-center">
        <h2 class="text-lg font-bold text-slate-800">Erreur de connexion</h2>
        <p class="text-xs text-slate-500 mt-1">Impossible de charger le menu. Veuillez vérifier votre connexion.</p>
        <button onclick="location.reload()" class="mt-4 px-4 py-2 bg-orange-600 text-white rounded-xl text-xs font-bold shadow">Réessayer</button>
      </div>
    `;
  }
}

initApp();
