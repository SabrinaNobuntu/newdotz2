import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Mail, Loader2, Lock, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/hooks/useAuth";
import { signUpSchema, signInSchema } from "@/lib/auth-schemas";
import { ZodError } from "zod";

export default function Auth() {
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();
  const { signUp, signIn } = useAuth();
  const navigate = useNavigate();

  // ---------------- SIGNUP ----------------
  const [signUpData, setSignUpData] = useState({
    email: "",
    password: "",
    name: "",
    role: "user" as "user" | "admin",
    adminCode: "",
  });

  // ---------------- SIGNIN ----------------
  const [signInData, setSignInData] = useState({
    email: "",
    password: "",
  });

  // ---------------- HANDLE SIGNUP ----------------
  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const validated = signUpSchema.parse(signUpData);
      const { data, error } = await signUp(validated);

      if (error) {
        toast({
          title: "Erro ao criar conta",
          description: error.message,
          variant: "destructive",
        });
        return;
      }

      if (data?.user) {
        toast({
          title: "Conta criada com sucesso!",
          description: "Verifique seu email para confirmar o cadastro.",
        });
        navigate("/");
      }
    } catch (err: unknown) {
      if (err instanceof ZodError) {
        toast({
          title: "Dados inválidos",
          description: err.errors[0]?.message,
          variant: "destructive",
        });
      }
    } finally {
      setLoading(false);
    }
  };

  // ---------------- HANDLE SIGNIN ----------------
  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const validated = signInSchema.parse(signInData);
      const { error } = await signIn(validated);

      if (error) {
        toast({
          title: "Erro ao fazer login",
          description: error.message.includes("Invalid login credentials")
            ? "Email ou senha incorretos."
            : error.message,
          variant: "destructive",
        });
        return;
      }

      toast({
        title: "Login realizado!",
        description: "Bem-vindo de volta.",
      });

      navigate("/");
    } catch (err: unknown) {
      if (err instanceof ZodError) {
        toast({
          title: "Dados inválidos",
          description: err.errors[0]?.message,
          variant: "destructive",
        });
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-background to-muted p-4">
      <Card className="w-full max-w-md border-0 shadow-2xl">
        <CardHeader className="text-center space-y-2">
          <CardTitle className="text-3xl font-bold bg-gradient-to-r from-brand-primary to-brand-secondary bg-clip-text text-transparent">
            Sistema de Pontos
          </CardTitle>
          <CardDescription className="text-base">
            Acesse sua conta ou crie uma nova
          </CardDescription>
        </CardHeader>

        <CardContent>
          <Tabs defaultValue="signin" className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="signin">Entrar</TabsTrigger>
              <TabsTrigger value="signup">Cadastrar</TabsTrigger>
            </TabsList>

            {/* ====================== LOGIN ====================== */}
            <TabsContent value="signin">
              <form onSubmit={handleSignIn} className="space-y-4 mt-4">
                {/* Email */}
                <div className="space-y-2">
                  <Label htmlFor="signin-email">Email</Label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="signin-email"
                      type="email"
                      placeholder="seu.email@empresa.com"
                      value={signInData.email}
                      onChange={(e) =>
                        setSignInData({ ...signInData, email: e.target.value })
                      }
                      className="pl-10"
                      required
                    />
                  </div>
                </div>

                {/* Senha */}
                <div className="space-y-2">
                  <Label htmlFor="signin-password">Senha</Label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="signin-password"
                      type="password"
                      placeholder="••••••••"
                      value={signInData.password}
                      onChange={(e) =>
                        setSignInData({
                          ...signInData,
                          password: e.target.value,
                        })
                      }
                      className="pl-10"
                      required
                    />
                  </div>
                </div>

                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Entrando...
                    </>
                  ) : (
                    "Entrar"
                  )}
                </Button>
              </form>
            </TabsContent>

            {/* ====================== CADASTRO ====================== */}
            <TabsContent value="signup">
              <form onSubmit={handleSignUp} className="space-y-4 mt-4">

                {/* Seleção de tipo de conta */}
                <div className="grid grid-cols-2 gap-2 mb-2">
                  <Button
                    type="button"
                    variant={signUpData.role === "user" ? "default" : "outline"}
                    onClick={() =>
                      setSignUpData({ ...signUpData, role: "user" })
                    }
                  >
                    Colaborador
                  </Button>

                  <Button
                    type="button"
                    variant={signUpData.role === "admin" ? "default" : "outline"}
                    onClick={() =>
                      setSignUpData({ ...signUpData, role: "admin" })
                    }
                  >
                    Administrador
                  </Button>
                </div>

                {/* Código Admin */}
                {signUpData.role === "admin" && (
                  <div className="space-y-2 animate-in fade-in slide-in-from-top-2">
                    <Label htmlFor="admin-code" className="text-destructive">
                      Código de Segurança Admin
                    </Label>
                    <Input
                      id="admin-code"
                      type="password"
                      placeholder="Código da empresa"
                      value={signUpData.adminCode}
                      onChange={(e) =>
                        setSignUpData({
                          ...signUpData,
                          adminCode: e.target.value,
                        })
                      }
                      required
                    />
                  </div>
                )}

                {/* Nome */}
                <div className="space-y-2">
                  <Label htmlFor="signup-name">Nome (opcional)</Label>
                  <div className="relative">
                    <User className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="signup-name"
                      type="text"
                      placeholder="Seu nome"
                      value={signUpData.name}
                      onChange={(e) =>
                        setSignUpData({ ...signUpData, name: e.target.value })
                      }
                      className="pl-10"
                    />
                  </div>
                </div>

                {/* Email */}
                <div className="space-y-2">
                  <Label htmlFor="signup-email">Email</Label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="signup-email"
                      type="email"
                      placeholder="seu.email@empresa.com"
                      value={signUpData.email}
                      onChange={(e) =>
                        setSignUpData({ ...signUpData, email: e.target.value })
                      }
                      className="pl-10"
                      required
                    />
                  </div>
                </div>

                {/* Senha */}
                <div className="space-y-2">
                  <Label htmlFor="signup-password">Senha</Label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                    <Input
                      id="signup-password"
                      type="password"
                      placeholder="Mínimo 6 caracteres"
                      value={signUpData.password}
                      onChange={(e) =>
                        setSignUpData({
                          ...signUpData,
                          password: e.target.value,
                        })
                      }
                      className="pl-10"
                      required
                    />
                  </div>
                </div>

                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Criando conta...
                    </>
                  ) : (
                    "Criar conta"
                  )}
                </Button>
              </form>
            </TabsContent>
          </Tabs>

          <p className="mt-6 text-center text-sm text-muted-foreground">
            Problemas com acesso? Entre em contato com o RH
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
