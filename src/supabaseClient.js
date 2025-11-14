import { createClient } from "@supabase/supabase-js";

// Substitua pelos dados que você copiou no Passo 1
const supabaseUrl = "https://skytjbggiqyprzkvqltz.supabase.co";
const supabaseAnonKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNreXRqYmdnaXF5cHJ6a3ZxbHR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI5OTAwMTYsImV4cCI6MjA3ODU2NjAxNn0.F6uOIEc01JlSJowHeDyE59l1-oJvVLQGCie7-CLlx54";

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
