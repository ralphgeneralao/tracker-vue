import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabaseKey = (
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  ""
).trim();

export let supabaseConfigError = "";
export let supabase = null;

if (!supabaseUrl || !supabaseKey) {
  supabaseConfigError =
    "Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in .env.";
} else {
  try {
    supabase = createClient(supabaseUrl, supabaseKey);
  } catch (error) {
    supabaseConfigError = `Invalid Supabase configuration: ${error.message}`;
  }
}

export const supabaseConfigAvailable = supabase !== null;
