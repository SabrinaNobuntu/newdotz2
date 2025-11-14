// src/hooks/useAuth.ts

import { useState, useEffect } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { SignUpInput, SignInInput } from '@/lib/auth-schemas';

// Correta leitura de variáveis de ambiente
const envUrl = import.meta.env?.VITE_SUPABASE_URL as string | undefined;
const envKey = import.meta.env?.VITE_SUPABASE_ANON_KEY as string | undefined;

const isDevelopmentMode =
  !envUrl ||
  !envKey ||
  envUrl === 'https://placeholder.supabase.co' ||
  envKey === 'placeholder-key';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  // ---------------------------------------------------------------------
  // LISTENER DE AUTENTICAÇÃO
  // ---------------------------------------------------------------------
  useEffect(() => {
    if (isDevelopmentMode) {
      const localUser = localStorage.getItem('dev_user'); // (REMOVIDO "a")

      if (localUser) {
        const userData = JSON.parse(localUser);

        setUser(userData as unknown as User);
        setSession({ user: userData } as unknown as Session);
      }

      setLoading(false);
      return;
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, sessionValue) => {
        setSession(sessionValue);
        setUser(sessionValue?.user ?? null);
        setLoading(false);
      }
    );

    supabase.auth.getSession().then(({ data: { session: sessionValue } }) => {
      setSession(sessionValue);
      setUser(sessionValue?.user ?? null);
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  // ---------------------------------------------------------------------
  // SIGNUP (Cadastro)
  // ---------------------------------------------------------------------
  const signUp = async ({ email, password, name, role }: SignUpInput) => {
    if (isDevelopmentMode) {
      const mockUser = {
        id: crypto.randomUUID(),
        email,
        user_metadata: {
          name: name || email.split('@')[0],
          role,
        },
        app_metadata: { role },
        created_at: new Date().toISOString(),
      };

      localStorage.setItem('dev_user', JSON.stringify(mockUser));
      setUser(mockUser as unknown as User);
      setSession({ user: mockUser } as unknown as Session);

      return {
        data: {
          user: mockUser as unknown as User,
          session: { user: mockUser } as unknown as Session,
        },
        error: null,
      };
    }

    const redirectUrl = `${window.location.origin}/`;

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: redirectUrl,
        data: {
          name: name || email.split('@')[0],
          role: role,
        },
      },
    });

    return { data, error };
  };

  // ---------------------------------------------------------------------
  // SIGNIN (Login)
  // ---------------------------------------------------------------------
  const signIn = async ({ email, password }: SignInInput) => {
    if (isDevelopmentMode) {
      const mockUser = {
        id: crypto.randomUUID(),
        email,
        user_metadata: { name: email.split('@')[0] },
        app_metadata: {
          role: email === 'admin@sistema.com' ? 'admin' : 'user',
        },
        created_at: new Date().toISOString(),
      };

      localStorage.setItem('dev_user', JSON.stringify(mockUser));
      setUser(mockUser as unknown as User);
      setSession({ user: mockUser } as unknown as Session);

      return {
        data: {
          user: mockUser as unknown as User,
          session: { user: mockUser } as unknown as Session,
        },
        error: null,
      };
    }

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    return { data, error };
  };

  // ---------------------------------------------------------------------
  // SIGNOUT (Logout)
  // ---------------------------------------------------------------------
  const signOut = async () => {
    if (isDevelopmentMode) {
      localStorage.removeItem('dev_user');
      setUser(null);
      setSession(null);
      return { error: null };
    }

    const { error } = await supabase.auth.signOut();
    return { error };
  };

  // ---------------------------------------------------------------------
  // CHECK ADMIN
  // ---------------------------------------------------------------------
  const checkIsAdmin = async (userId: string): Promise<boolean> => {
    if (isDevelopmentMode) {
      const localUser = localStorage.getItem('dev_user');

      if (localUser) {
        const userData = JSON.parse(localUser);
        return userData.app_metadata?.role === 'admin';
      }

      return false;
    }

    const { data } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .eq('role', 'admin')
      .single();

    return !!data;
  };

  return {
    user,
    session,
    loading,
    signUp,
    signIn,
    signOut,
    checkIsAdmin,
  };
}
