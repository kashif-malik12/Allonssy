import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://supabase.allonssy.com';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzczMzk5MzMwLCJleHAiOjIwODg3NTkzMzB9.iujKi-cLEPYQklHsS1VI-FNc8WVKwi9sMtqbS4AAIjw';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
