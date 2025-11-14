// src/pages/Index.tsx

import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Layout } from "@/components/Layout";
import { Header } from "@/components/Header";
import { Dashboard } from "@/components/Dashboard";
import { SurveyForm } from "@/components/SurveyForm";
import { ReferralForm } from "@/components/ReferralForm";
import { RewardsShop } from "@/components/RewardsShop";
import { AdminDashboard } from "@/components/AdminDashboard";
import { MaterialsPage } from "@/pages/MaterialsPage";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabase";
import { Database } from "@/lib/supabase-types";
import { Loader2 } from "lucide-react";

type ProfileRow = Database['public']['Tables']['profiles']['Row'];
type View = 'dashboard' | 'survey' | 'referral' | 'rewards' | 'admin' | 'materials';

const Index = () => {
  const [currentView, setCurrentView] = useState<View>('dashboard');
  const [userPoints, setUserPoints] = useState(0);
  const [userName, setUserName] = useState<string | undefined>();
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  const { user, signOut, checkIsAdmin } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) {
      loadUserData();
    }
  }, [user]);

  const loadUserData = async () => {
    if (!user) return;

    setLoading(true);

    // 1. Carregar dados do perfil do usuário
    const { data, error } = await supabase
      .from("profiles")
      .select("name, points")
      .eq("id", user.id)
      .single<Pick<ProfileRow, "name" | "points">>();

    if (!error && data) {
      setUserName(data.name ?? user.email?.split("@")[0]);
      setUserPoints(data.points ?? 0);
    }

    // 2. Verificar se o usuário é admin
    const adminStatus = await checkIsAdmin(user.id);
    setIsAdmin(adminStatus);

    // 3. NOVA LÓGICA — Redirecionamento Automático
    if (adminStatus) {
      setCurrentView("admin"); // Vai direto para o Admin Dashboard
    } else {
      setCurrentView("dashboard"); // Usuário comum → Dashboard normal
    }

    setLoading(false);
  };

  const handleSignOut = async () => {
    await signOut();
    navigate("/auth");
  };

  const handleNavigate = (view: View) => {
    setCurrentView(view);
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-brand-primary" />
      </div>
    );
  }

  return (
    <Layout>
      <div className="space-y-6">

        <Header
          userName={userName}
          userEmail={user?.email}
          points={userPoints}
          isAuthenticated={!!user}
          onSignOut={handleSignOut}
          onAdminAccess={isAdmin ? () => handleNavigate("admin") : undefined}
        />

        {currentView === "dashboard" && (
          <Dashboard
            userName={userName}
            points={userPoints}
            onNavigate={handleNavigate}
          />
        )}

        {currentView === "survey" && (
          <SurveyForm onBack={() => handleNavigate("dashboard")} />
        )}

        {currentView === "referral" && (
          <ReferralForm onBack={() => handleNavigate("dashboard")} />
        )}

        {currentView === "rewards" && (
          <RewardsShop
            userPoints={userPoints}
            onBack={() => handleNavigate("dashboard")}
          />
        )}

        {currentView === "materials" && (
          <MaterialsPage onBack={() => handleNavigate("dashboard")} />
        )}

        {currentView === "admin" && isAdmin && (
          <AdminDashboard onBack={() => handleNavigate("dashboard")} />
        )}
      </div>
    </Layout>
  );
};

export default Index;
