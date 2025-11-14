// src/lib/auth-schemas.ts
import { z } from "zod";

export const signUpSchema = z.object({
  email: z
    .string()
    .trim()
    .email({ message: "Email inválido" })
    .max(255),
  password: z
    .string()
    .min(6, { message: "Senha deve ter no mínimo 6 caracteres" }),
  name: z
    .string()
    .trim()
    .min(2, { message: "Nome deve ter no mínimo 2 caracteres" })
    .optional(),
  role: z.enum(["admin", "user"]), // Adicionado campo role
  adminCode: z.string().optional(), // Código de segurança para admins
}).refine((data) => {
  // Se escolher admin, o código é obrigatório (Exemplo de código: "SISTEMA2024")
  if (data.role === 'admin' && data.adminCode !== 'SISTEMA2024') {
    return false;
  }
  return true;
}, {
  message: "Código de administrador inválido",
  path: ["adminCode"],
});

// ... mantenha o signInSchema como está
export const signInSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export type SignUpInput = z.infer<typeof signUpSchema>;
export type SignInInput = z.infer<typeof signInSchema>;