import { createBrowserRouter } from "react-router";
import {
  Landing, Login, Onboarding, AppShell, RequireAuth, NotFound,
  Dashboard, Documents, Entries, Billing, Assistant, KPIs, SettingsScreen,
} from "./App";

const AUTH_KEY = "aionis_auth";
export const isAuthed = () => typeof window !== "undefined" && localStorage.getItem(AUTH_KEY) === "1";
export const login = () => localStorage.setItem(AUTH_KEY, "1");
export const logout = () => localStorage.removeItem(AUTH_KEY);

export const router = createBrowserRouter([
  { path: "/", Component: Landing },
  { path: "/login", Component: Login },
  { path: "/onboarding", Component: Onboarding },
  {
    path: "/app",
    element: (
      <RequireAuth>
        <AppShell />
      </RequireAuth>
    ),
    children: [
      { index: true, Component: Dashboard },
      { path: "dashboard", Component: Dashboard },
      { path: "documentos", Component: Documents },
      { path: "lancamentos", Component: Entries },
      { path: "contas", Component: Billing },
      { path: "assistente", Component: Assistant },
      { path: "saude", Component: KPIs },
      { path: "configuracoes", Component: SettingsScreen },
    ],
  },
  { path: "*", Component: NotFound },
]);
