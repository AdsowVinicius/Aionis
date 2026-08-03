import { useState, useEffect } from "react";
import {
  Sparkles, MessageCircle, Mail, Upload, ArrowRight, Check, Shield,
  Bell, TrendingUp, TrendingDown, Wallet, Receipt, FileText, Bot,
  LayoutDashboard, FileSpreadsheet, CreditCard, Settings, Activity,
  Search, Plus, ChevronRight, AlertTriangle, CheckCircle2, Clock,
  XCircle, Eye, Filter, Download, Send, Heart, Zap, ChevronLeft,
  Building2, User, Users, LogOut, Calendar, BarChart3,
  Banknote, ArrowUpRight, ArrowDownRight, Paperclip, RotateCcw,
  Lock, Smartphone, Globe, ChevronDown, X, Flame, Star, Award, Timer,
  PhoneCall, ShieldCheck, Crown, Minus,
} from "lucide-react";
import {
  AreaChart, Area, BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  ResponsiveContainer, XAxis, YAxis, Tooltip, CartesianGrid,
} from "recharts";

/* ============================================================
   Aionis — financial SaaS prototype
   ============================================================ */

import { RouterProvider, NavLink, useNavigate, useLocation, Outlet, Navigate, Link } from "react-router";
import { router, isAuthed, login as authLogin, logout as authLogout } from "./routes";

export const screens = [
  { path: "/app/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { path: "/app/documentos", label: "Documentos", icon: FileText },
  { path: "/app/lancamentos", label: "Lançamentos", icon: FileSpreadsheet },
  { path: "/app/contas", label: "Contas", icon: CreditCard },
  { path: "/app/assistente", label: "Assistente IA", icon: Bot },
  { path: "/app/saude", label: "Saúde Financeira", icon: Activity },
  { path: "/app/configuracoes", label: "Configurações", icon: Settings },
];

/* ---------- Brand mark ---------- */
function Logo({ size = 28, mono = false }: { size?: number; mono?: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <div
        className="relative flex items-center justify-center rounded-[14px]"
        style={{
          width: size, height: size,
          background: mono ? "rgba(255,255,255,0.08)" : "linear-gradient(135deg,#0E1B2C 0%, #14B88A 130%)",
        }}
      >
        <svg viewBox="0 0 24 24" width={size * 0.6} height={size * 0.6} fill="none">
          <path d="M4 18 L12 4 L20 18" stroke="#14B88A" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/>
          <path d="M8 14 L16 14" stroke="#fff" strokeWidth="2.4" strokeLinecap="round"/>
        </svg>
      </div>
      <span className={`font-display tracking-tight ${mono ? "text-white" : "text-[#0E1B2C]"}`} style={{ fontWeight: 800, fontSize: size * 0.62 }}>
        Aionis
      </span>
    </div>
  );
}

/* ============================================================
   ROOT
   ============================================================ */
export default function App() {
  return <RouterProvider router={router} />;
}

export function RequireAuth({ children }: { children: any }) {
  const loc = useLocation();
  if (!isAuthed()) return <Navigate to="/login" state={{ from: loc.pathname }} replace />;
  return <>{children}</>;
}

export function NotFound() {
  return (
    <div className="min-h-screen bg-[#F5F4EF] flex items-center justify-center px-6">
      <div className="text-center max-w-md">
        <div className="inline-flex mb-6"><Logo size={36}/></div>
        <div className="font-display text-[120px] leading-none text-[#0E1B2C]">404</div>
        <h1 className="font-display text-2xl mt-2">Página não encontrada</h1>
        <p className="text-[#6B7385] mt-3">O endereço que você tentou acessar não existe ou foi movido.</p>
        <Link to="/" className="inline-flex mt-8 h-12 px-6 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white items-center gap-2">
          <ArrowRight size={16} className="rotate-180"/> Voltar para a home
        </Link>
      </div>
    </div>
  );
}

/* ============================================================
   LANDING
   ============================================================ */
function CountdownPill() {
  const [t, setT] = useState({ h: 23, m: 47, s: 12 });
  useEffect(() => {
    const i = setInterval(() => {
      setT((p) => {
        let { h, m, s } = p;
        s--;
        if (s < 0) { s = 59; m--; }
        if (m < 0) { m = 59; h--; }
        if (h < 0) { h = 23; }
        return { h, m, s };
      });
    }, 1000);
    return () => clearInterval(i);
  }, []);
  const pad = (n: number) => String(n).padStart(2, "0");
  return (
    <span className="font-mono text-white">
      {pad(t.h)}:{pad(t.m)}:{pad(t.s)}
    </span>
  );
}

export function Landing() {
  const navigate = useNavigate();
  const onCta = () => navigate("/login");
  return (
    <div className="min-h-screen bg-[#F5F4EF] text-[#0E1B2C]">
      {/* Urgency bar */}
      <div className="bg-[#0E1B2C] text-white text-xs">
        <div className="max-w-7xl mx-auto px-6 h-10 flex items-center justify-center gap-3 flex-wrap">
          <Flame size={14} className="text-[#F59E0B]"/>
          <span className="font-semibold">OFERTA DE LANÇAMENTO:</span>
          <span className="text-white/80">3 meses com <b className="text-[#14B88A]">50% OFF</b> + implantação grátis</span>
          <span className="text-white/40">·</span>
          <span className="text-white/80">termina em</span>
          <CountdownPill/>
          <button onClick={onCta} className="ml-1 underline hover:text-[#14B88A]">Garantir agora →</button>
        </div>
      </div>

      {/* Nav */}
      <header className="sticky top-0 z-40 backdrop-blur bg-white/80 border-b border-border">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <Logo />
          <nav className="hidden md:flex items-center gap-8 text-sm text-[#6B7385]">
            <a href="#dor" className="hover:text-[#0E1B2C]">Por que Aionis</a>
            <a href="#fluxo" className="hover:text-[#0E1B2C]">Como funciona</a>
            <a href="#planos" className="hover:text-[#0E1B2C]">Planos</a>
            <a href="#faq" className="hover:text-[#0E1B2C]">FAQ</a>
          </nav>
          <div className="flex items-center gap-3">
            <button onClick={onCta} className="text-sm text-[#0E1B2C] hover:opacity-70">Entrar</button>
            <button onClick={onCta} className="bg-[#14B88A] hover:bg-[#0ea273] text-white text-sm px-4 h-10 rounded-[14px] flex items-center gap-2 transition shadow-[0_8px_24px_-8px_rgba(16,185,129,0.6)]">
              Testar grátis <ArrowRight size={16}/>
            </button>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 -z-10">
          <div className="absolute -top-32 -right-32 w-[520px] h-[520px] rounded-full opacity-30"
            style={{ background: "radial-gradient(circle, #14B88A 0%, transparent 60%)"}}/>
          <div className="absolute top-40 -left-20 w-[420px] h-[420px] rounded-full opacity-20"
            style={{ background: "radial-gradient(circle, #38BDF8 0%, transparent 60%)"}}/>
        </div>
        <div className="max-w-7xl mx-auto px-6 pt-16 pb-24 grid lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-7">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-[#0E1B2C] text-white text-xs mb-6">
              <Flame size={12} className="text-[#F59E0B]"/>
              <span>+2.847 empresários já organizaram o financeiro com Aionis</span>
            </div>
            <h1 className="font-display text-5xl md:text-[64px] leading-[1.02] tracking-tight">
              Pare de <span className="line-through text-[#DC2657]/70 decoration-[3px]">perder dinheiro</span> com planilha bagunçada.
              <br/>
              <span className="text-[#14B88A]">Mande pelo WhatsApp.</span> A IA organiza pra você.
            </h1>
            <p className="mt-6 text-lg text-[#6B7385] max-w-2xl leading-relaxed">
              Notas, comprovantes e despesas viram lançamentos, KPIs e alertas em <b className="text-[#0E1B2C]">menos de 30 segundos</b>.
              Sem digitação. Sem ERP. Sem dor de cabeça.
            </p>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <button onClick={onCta} className="bg-[#14B88A] hover:bg-[#0ea273] text-white h-14 px-7 rounded-[14px] flex items-center gap-2 transition shadow-[0_16px_40px_-12px_rgba(16,185,129,0.6)]">
                Quero testar 14 dias grátis <ArrowRight size={20}/>
              </button>
              <button className="bg-white border border-border h-14 px-6 rounded-[14px] flex items-center gap-2 hover:border-[#0E1B2C]/30 transition">
                <span className="w-8 h-8 rounded-full bg-[#14B88A]/10 flex items-center justify-center">
                  <span className="w-0 h-0 border-l-[8px] border-l-[#14B88A] border-y-[6px] border-y-transparent ml-0.5"/>
                </span>
                Ver demonstração de 90s
              </button>
            </div>

            <div className="mt-5 flex items-center gap-4 text-xs text-[#6B7385]">
              <span className="flex items-center gap-1.5"><Check size={14} className="text-[#14B88A]"/> Sem cartão de crédito</span>
              <span className="flex items-center gap-1.5"><Check size={14} className="text-[#14B88A]"/> Cancele quando quiser</span>
              <span className="flex items-center gap-1.5"><Check size={14} className="text-[#14B88A]"/> Setup em 3 minutos</span>
            </div>

            {/* social proof inline */}
            <div className="mt-10 flex items-center gap-5">
              <div className="flex -space-x-2">
                {["#14B88A","#0E1B2C","#38BDF8","#F59E0B","#8B5CF6"].map((c, i) => (
                  <div key={i} className="w-9 h-9 rounded-full border-2 border-white" style={{ background: c }}/>
                ))}
              </div>
              <div>
                <div className="flex items-center gap-1">
                  {[1,2,3,4,5].map((s) => <Star key={s} size={14} className="text-[#F59E0B] fill-[#F59E0B]"/>)}
                  <span className="text-sm font-semibold ml-1">4,9/5</span>
                </div>
                <div className="text-xs text-[#6B7385]">312 avaliações de MEIs e pequenas empresas</div>
              </div>
            </div>
          </div>

          {/* Hero mock */}
          <div className="lg:col-span-5 relative">
            <HeroMock />
          </div>
        </div>

        {/* Logos */}
        <div className="border-y border-border bg-white/60">
          <div className="max-w-7xl mx-auto px-6 py-8 flex flex-wrap items-center justify-center gap-x-12 gap-y-4">
            <div className="text-xs uppercase tracking-wider text-[#6B7385]">Citado em</div>
            {["EXAME","Pequenas Empresas","Sebrae","InfoMoney","Contábeis","Endeavor"].map((l) => (
              <div key={l} className="font-display font-bold text-[#0E1B2C]/40 hover:text-[#0E1B2C]/70 transition">{l}</div>
            ))}
          </div>
        </div>
      </section>

      {/* DOR / Problema */}
      <section id="dor" className="bg-white">
        <div className="max-w-7xl mx-auto px-6 py-24 grid lg:grid-cols-2 gap-16 items-center">
          <div>
            <div className="text-xs uppercase tracking-[0.18em] text-[#DC2657] mb-3">A real é dura</div>
            <h2 className="font-display text-4xl md:text-5xl leading-tight">
              Se você ainda usa <span className="text-[#DC2657]">planilha</span>, está perdendo dinheiro <span className="italic">todo mês.</span>
            </h2>
            <p className="mt-5 text-[#6B7385] text-lg">
              68% dos MEIs e PMEs descobrem prejuízo só quando já é tarde. Não por falta de trabalho — por falta de organização.
            </p>
          </div>
          <div className="space-y-3">
            {[
              "Você esquece contas vencendo e paga multa.",
              "Não sabe quanto sobra de verdade no fim do mês.",
              "Mistura CPF e CNPJ e o contador cobra extra.",
              "Comprovantes somem ou vencem no e-mail.",
              "Gasta 6h por mês digitando nota em planilha.",
              "Não tem visão real do caixa pros próximos 30 dias.",
            ].map((t) => (
              <div key={t} className="flex items-start gap-3 p-4 rounded-[14px] bg-[#FBEBEE]/40 border border-[#DC2657]/15">
                <div className="w-6 h-6 rounded-full bg-[#DC2657]/15 text-[#DC2657] flex items-center justify-center shrink-0 mt-0.5">
                  <X size={14}/>
                </div>
                <div className="text-sm font-medium text-[#0E1B2C]">{t}</div>
              </div>
            ))}
            <div className="mt-4 p-5 rounded-[14px] bg-[#0E1B2C] text-white flex items-center gap-3">
              <Sparkles size={20} className="text-[#14B88A]"/>
              <div className="text-sm">
                <b className="text-[#14B88A]">Aionis resolve tudo isso</b> em uma única conversa de WhatsApp.
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 3 passos */}
      <section id="fluxo" className="max-w-7xl mx-auto px-6 py-24">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <div className="text-xs uppercase tracking-[0.18em] text-[#14B88A] mb-3">Como funciona</div>
          <h2 className="font-display text-4xl md:text-5xl">3 passos. Zero planilha. 30 segundos.</h2>
          <p className="mt-4 text-[#6B7385] text-lg">Mais rápido que escrever um e-mail.</p>
        </div>
        <div className="grid md:grid-cols-3 gap-6">
          {[
            { n: "01", icon: Send, title: "Envie a nota ou comprovante", text: "WhatsApp, e-mail ou upload no portal. Foto, PDF, XML — tudo aceito.", time: "5s" },
            { n: "02", icon: Sparkles, title: "A IA interpreta e classifica", text: "Identifica valor, fornecedor, categoria e gera o lançamento sozinha.", time: "15s" },
            { n: "03", icon: BarChart3, title: "Acompanhe KPIs e alertas", text: "Saúde financeira, fluxo de caixa, vencimentos e avisos no tempo certo.", time: "tempo real" },
          ].map((s) => (
            <div key={s.n} className="group relative bg-white border border-border rounded-[20px] p-7 hover:border-[#14B88A]/40 hover:shadow-[0_8px_40px_-12px_rgba(11,26,47,0.12)] transition">
              <div className="flex items-center justify-between mb-6">
                <div className="font-mono text-xs text-[#14B88A]">{s.n}</div>
                <div className="flex items-center gap-1 text-[10px] uppercase tracking-wider text-[#6B7385] bg-[#F5F4EF] px-2 py-1 rounded-full">
                  <Timer size={10}/> {s.time}
                </div>
              </div>
              <div className="w-12 h-12 rounded-[14px] bg-[#0E1B2C] text-white flex items-center justify-center mb-5 group-hover:bg-[#14B88A] transition">
                <s.icon size={22}/>
              </div>
              <h3 className="font-display text-xl mb-2">{s.title}</h3>
              <p className="text-[#6B7385] text-sm leading-relaxed">{s.text}</p>
            </div>
          ))}
        </div>

        {/* Antes / Depois */}
        <div className="mt-16 grid md:grid-cols-2 gap-5">
          <div className="rounded-[20px] border-2 border-dashed border-[#DC2657]/30 p-7 bg-[#FBEBEE]/20">
            <div className="text-xs uppercase tracking-wider text-[#DC2657] font-semibold mb-3">Antes do Aionis</div>
            {[
              "6h/mês digitando planilha",
              "Esquece 2 a 3 contas por mês",
              "Não sabe se está no lucro",
              "Contador cobra R$ 400 de extra",
              "Comprovantes perdidos",
            ].map((t) => (
              <div key={t} className="flex items-center gap-2 py-2 text-sm text-[#0E1B2C]">
                <X size={16} className="text-[#DC2657]"/> {t}
              </div>
            ))}
          </div>
          <div className="rounded-[20px] border-2 border-[#14B88A] p-7 bg-[#E8F4EF]/40 relative">
            <div className="absolute -top-3 left-7 bg-[#14B88A] text-white text-[11px] font-semibold uppercase tracking-wider px-3 py-1 rounded-full">Com Aionis</div>
            <div className="text-xs uppercase tracking-wider text-[#14B88A] font-semibold mb-3">Depois do Aionis</div>
            {[
              "0h digitando — IA faz por você",
              "Alertas antes de cada vencimento",
              "Lucro real em tempo real",
              "Pacote pronto pro contador",
              "Tudo arquivado e buscável",
            ].map((t) => (
              <div key={t} className="flex items-center gap-2 py-2 text-sm text-[#0E1B2C] font-medium">
                <CheckCircle2 size={16} className="text-[#14B88A]"/> {t}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Resultados em números */}
      <section className="bg-[#0E1B2C] text-white relative overflow-hidden">
        <div className="absolute inset-0 opacity-30"
             style={{ background: "radial-gradient(circle at 80% 50%, rgba(16,185,129,0.5) 0%, transparent 50%)" }}/>
        <div className="relative max-w-7xl mx-auto px-6 py-20 grid md:grid-cols-4 gap-8 text-center">
          {[
            { v: "2.847", l: "Empresas usando hoje" },
            { v: "R$ 14M", l: "Movimentados no mês" },
            { v: "97%", l: "Recomendam pra um amigo" },
            { v: "30s", l: "Pra lançar 1 nota" },
          ].map((s) => (
            <div key={s.l}>
              <div className="font-display text-5xl text-[#14B88A]">{s.v}</div>
              <div className="text-sm text-white/60 mt-2">{s.l}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Depoimentos */}
      <section className="max-w-7xl mx-auto px-6 py-24">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <div className="text-xs uppercase tracking-[0.18em] text-[#14B88A] mb-3">Quem usa, fala</div>
          <h2 className="font-display text-4xl md:text-5xl">Empresários que dormem tranquilos agora.</h2>
        </div>
        <div className="grid md:grid-cols-3 gap-5">
          {[
            { n: "Camila Andrade", r: "MEI · Estúdio Lume", q: "Em 30 dias o Aionis tirou minha planilha do caos. Hoje sei exatamente quanto sobra no fim do mês — e até quanto posso me pagar.", g: "+R$ 4.200/mês descoberto" },
            { n: "Rodrigo Sales", r: "Pequena indústria · Tatuí", q: "Eu mandava nota pelo WhatsApp pra mim mesmo só pra lembrar. Hoje mando pro Aionis e ele lança, categoriza e ainda avisa quando vai vencer.", g: "0 contas vencidas em 4 meses" },
            { n: "Marina Coelho", r: "Restaurante · Pinheiros", q: "Meu contador pediu pra eu mudar TODOS meus clientes pro Aionis. Reduziu o trabalho dele em 80% e meus custos contábeis pela metade.", g: "−50% no contador" },
          ].map((d) => (
            <div key={d.n} className="bg-white rounded-[20px] border border-border p-7">
              <div className="flex items-center gap-1 mb-4">
                {[1,2,3,4,5].map((s) => <Star key={s} size={14} className="text-[#F59E0B] fill-[#F59E0B]"/>)}
              </div>
              <p className="text-[#0E1B2C] leading-relaxed">"{d.q}"</p>
              <div className="mt-5 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#E8F4EF] text-[#14B88A] text-xs font-semibold">
                <TrendingUp size={12}/> {d.g}
              </div>
              <div className="mt-5 flex items-center gap-3 pt-5 border-t border-border">
                <div className="w-11 h-11 rounded-full bg-gradient-to-br from-[#14B88A] to-[#0E1B2C]"/>
                <div>
                  <div className="font-semibold text-sm">{d.n}</div>
                  <div className="text-xs text-[#6B7385]">{d.r}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Comparação */}
      <section className="bg-white border-y border-border">
        <div className="max-w-6xl mx-auto px-6 py-24">
          <div className="text-center max-w-2xl mx-auto mb-14">
            <div className="text-xs uppercase tracking-[0.18em] text-[#14B88A] mb-3">Por que Aionis vence</div>
            <h2 className="font-display text-4xl md:text-5xl">Aionis vs. o que você usa hoje.</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr>
                  <th className="text-left p-4"></th>
                  <th className="p-4">
                    <div className="inline-flex items-center gap-2 bg-[#0E1B2C] text-white px-4 py-2 rounded-[14px]">
                      <Logo size={22} mono/>
                    </div>
                  </th>
                  <th className="p-4 font-display text-[#6B7385]">Planilha</th>
                  <th className="p-4 font-display text-[#6B7385]">ERP tradicional</th>
                  <th className="p-4 font-display text-[#6B7385]">Contador só</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ["Envio por WhatsApp", true, false, false, false],
                  ["IA lê e classifica nota", true, false, false, false],
                  ["Alertas de vencimento", true, false, true, false],
                  ["KPIs em tempo real", true, false, true, false],
                  ["Setup em 3 minutos", true, true, false, false],
                  ["Separação CPF/CNPJ", true, false, false, true],
                  ["Custa menos de R$ 100/mês", true, true, false, false],
                ].map((row: any, i) => (
                  <tr key={i} className="border-t border-border">
                    <td className="p-4 font-medium">{row[0]}</td>
                    {[1,2,3,4].map((j) => (
                      <td key={j} className="p-4 text-center">
                        {row[j]
                          ? <CheckCircle2 size={20} className={`mx-auto ${j === 1 ? "text-[#14B88A]" : "text-[#6B7385]"}`}/>
                          : <Minus size={18} className="mx-auto text-[#DC2657]/40"/>}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Benefícios */}
      <section id="beneficios" className="bg-white">
        <div className="max-w-7xl mx-auto px-6 py-20 grid lg:grid-cols-12 gap-12">
          <div className="lg:col-span-4">
            <div className="text-xs uppercase tracking-[0.18em] text-[#14B88A] mb-3">Benefícios</div>
            <h2 className="font-display text-4xl leading-tight">Tudo o que falta na sua rotina financeira.</h2>
            <p className="mt-5 text-[#6B7385]">Pensado para quem não tem tempo, nem paciência, para sistema de contador.</p>
          </div>
          <div className="lg:col-span-8 grid sm:grid-cols-2 gap-4">
            {[
              { icon: Zap, t: "Menos digitação manual", d: "A IA extrai dados do documento em segundos." },
              { icon: CreditCard, t: "Controle de contas a pagar", d: "Acompanhe vencimentos por status, valor e fornecedor." },
              { icon: Bell, t: "Alertas de vencimento", d: "Avisos antes do vencimento, no WhatsApp ou e-mail." },
              { icon: BarChart3, t: "Indicadores financeiros", d: "Saúde, margem, custo fixo, ponto de equilíbrio." },
              { icon: FileSpreadsheet, t: "Relatórios para contador", d: "Exportação em formato pronto para escritório." },
              { icon: Users, t: "Separação CPF / CNPJ", d: "Uma única conta, finanças bem separadas." },
            ].map((b) => (
              <div key={b.t} className="flex items-start gap-4 p-5 rounded-[14px] border border-border hover:bg-[#E8F4EF]/40 transition">
                <div className="w-10 h-10 rounded-lg bg-[#E8F4EF] text-[#14B88A] flex items-center justify-center shrink-0">
                  <b.icon size={18}/>
                </div>
                <div>
                  <div className="font-display font-semibold text-[#0E1B2C]">{b.t}</div>
                  <div className="text-sm text-[#6B7385] mt-1">{b.d}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Planos */}
      <section id="planos" className="max-w-7xl mx-auto px-6 py-24">
        <div className="text-center max-w-2xl mx-auto mb-12">
          <div className="text-xs uppercase tracking-[0.18em] text-[#14B88A] mb-3">Planos honestos</div>
          <h2 className="font-display text-4xl md:text-5xl">Menos que um almoço por semana.</h2>
          <p className="mt-4 text-[#6B7385] text-lg">
            14 dias grátis em todos os planos. <b className="text-[#0E1B2C]">Sem cartão de crédito.</b>
          </p>
          <div className="mt-5 inline-flex items-center gap-2 bg-[#FAF1DD] text-[#B26B00] px-4 py-2 rounded-full text-sm">
            <Flame size={14}/> Oferta de lançamento: <b>50% OFF nos 3 primeiros meses</b> — termina em <CountdownPill/>
          </div>
        </div>
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-5">
          {[
            { name: "CPF", price: "R$ 13", oldPrice: "R$ 26", per: "/mês nos 3 primeiros meses", desc: "Para autônomos e pessoa física.", features: ["WhatsApp + e-mail", "100 documentos/mês", "Alertas de vencimento", "Resumos mensais"], cta: "Começar grátis", badge: null, icon: User },
            { name: "MEI", price: "R$ 48", oldPrice: "R$ 97", per: "/mês nos 3 primeiros meses", desc: "Para microempreendedores individuais.", features: ["Tudo do CPF", "500 documentos/mês", "Contas a pagar/receber", "Relatórios para contador", "Assistente IA ilimitado"], cta: "Começar grátis", highlight: true, badge: "Mais escolhido · 78%", icon: Receipt },
            { name: "Pro", price: "R$ 98", oldPrice: "R$ 197", per: "/mês + implantação grátis", desc: "Para pequenas empresas em crescimento.", features: ["Documentos ilimitados", "Multiusuário (até 5)", "KPIs avançados", "Suporte prioritário", "Onboarding 1-a-1"], cta: "Falar com vendas", badge: "Melhor custo-benefício", icon: Building2 },
            { name: "Gestão", price: "Sob consulta", oldPrice: "", per: "", desc: "Para operações com necessidades específicas.", features: ["Integrações sob medida", "SLA dedicado", "Onboarding assistido", "API e BI", "Gerente dedicado"], cta: "Fale conosco", badge: null, icon: Crown },
          ].map((p: any) => (
            <div key={p.name} className={`relative rounded-[20px] p-7 border transition ${
              p.highlight
                ? "bg-[#0E1B2C] text-white border-[#0E1B2C] shadow-[0_24px_60px_-20px_rgba(11,26,47,0.4)]"
                : "bg-white border-border hover:border-[#14B88A]/40"
            }`}>
              {p.badge && (
                <div className={`absolute -top-3 left-7 text-[11px] font-semibold uppercase tracking-wider px-3 py-1 rounded-full ${
                  p.highlight ? "bg-[#14B88A] text-white" : "bg-[#0E1B2C] text-white"
                }`}>
                  {p.badge}
                </div>
              )}
              <div className="flex items-center justify-between">
                <div className="text-xs uppercase tracking-wider opacity-70">Aionis</div>
                <p.icon size={18} className={p.highlight ? "text-[#14B88A]" : "text-[#6B7385]"}/>
              </div>
              <div className="font-display text-3xl mt-1">{p.name}</div>
              {p.oldPrice && (
                <div className={`mt-4 text-sm line-through ${p.highlight ? "text-white/40" : "text-[#6B7385]"}`}>
                  De {p.oldPrice}/mês
                </div>
              )}
              <div className={`${p.oldPrice ? "mt-1" : "mt-5"} flex items-baseline gap-1`}>
                <span className="font-display text-3xl">{p.price}</span>
                <span className="opacity-60 text-xs">{p.per}</span>
              </div>
              <p className={`mt-3 text-sm ${p.highlight ? "text-white/70" : "text-[#6B7385]"}`}>{p.desc}</p>
              <ul className="mt-6 space-y-2.5">
                {p.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm">
                    <Check size={16} className={p.highlight ? "text-[#14B88A] mt-0.5" : "text-[#14B88A] mt-0.5"}/>
                    <span className={p.highlight ? "text-white/90" : "text-[#0E1B2C]"}>{f}</span>
                  </li>
                ))}
              </ul>
              <button className={`mt-7 w-full h-11 rounded-[14px] text-sm font-semibold transition ${
                p.highlight ? "bg-[#14B88A] hover:bg-[#0ea273] text-white" : "bg-[#0E1B2C] hover:bg-[#15243d] text-white"
              }`}>
                {p.cta}
              </button>
            </div>
          ))}
        </div>

        {/* Garantia */}
        <div className="mt-10 max-w-3xl mx-auto rounded-[20px] border-2 border-[#14B88A]/30 bg-[#E8F4EF]/40 p-7 flex items-center gap-5">
          <div className="w-16 h-16 rounded-[20px] bg-[#14B88A] text-white flex items-center justify-center shrink-0">
            <ShieldCheck size={30}/>
          </div>
          <div>
            <div className="font-display text-xl text-[#0E1B2C]">Garantia incondicional de 30 dias</div>
            <p className="text-sm text-[#6B7385] mt-1">
              Testou e não amou? Devolvemos <b className="text-[#14B88A]">100% do seu dinheiro</b>. Sem perguntas, sem letrinha miúda. O risco é todo nosso.
            </p>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <FAQ/>

      {/* CTA final */}
      <section className="px-6 pb-24">
        <div className="max-w-6xl mx-auto rounded-[28px] bg-[#0E1B2C] text-white px-10 py-20 relative overflow-hidden">
          <div className="absolute inset-0 opacity-50"
               style={{ background: "radial-gradient(circle at 80% 30%, rgba(16,185,129,0.5) 0%, transparent 50%)" }}/>
          <div className="absolute -bottom-20 -left-20 w-80 h-80 rounded-full opacity-20"
               style={{ background: "radial-gradient(circle, #38BDF8 0%, transparent 60%)"}}/>
          <div className="relative max-w-3xl">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-[#14B88A]/20 text-[#14B88A] text-xs font-semibold uppercase tracking-wider mb-6">
              <Flame size={12}/> Última chamada
            </div>
            <h2 className="font-display text-4xl md:text-6xl leading-[1.05] tracking-tight">
              Organize seu financeiro <span className="text-[#14B88A]">antes</span> que ele vire um problema.
            </h2>
            <p className="mt-6 text-white/70 text-lg leading-relaxed">
              Toda semana que você adia é mais dinheiro escapando. Comece hoje em 3 minutos —
              <b className="text-white"> 14 dias grátis</b>, sem cartão de crédito.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <button onClick={onCta} className="bg-[#14B88A] hover:bg-[#0ea273] h-14 px-7 rounded-[14px] flex items-center gap-2 shadow-[0_16px_40px_-12px_rgba(16,185,129,0.6)]">
                Quero meus 14 dias grátis <ArrowRight size={20}/>
              </button>
              <button className="bg-white/10 hover:bg-white/15 h-14 px-7 rounded-[14px] flex items-center gap-2">
                <PhoneCall size={18}/> Falar com vendas
              </button>
            </div>
            <div className="mt-6 flex items-center gap-5 text-xs text-white/60">
              <span className="flex items-center gap-1.5"><Check size={14} className="text-[#14B88A]"/> Garantia 30 dias</span>
              <span className="flex items-center gap-1.5"><Check size={14} className="text-[#14B88A]"/> Cancele quando quiser</span>
              <span className="flex items-center gap-1.5"><Award size={14} className="text-[#14B88A]"/> 4,9/5 · 312 avaliações</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border bg-white">
        <div className="max-w-7xl mx-auto px-6 py-10 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-3 text-sm text-[#6B7385]">
            <Logo size={22}/>
            <span>— seu financeiro organizado, inteligente e sem complicação.</span>
          </div>
          <div className="text-xs text-[#6B7385]">© 2026 Aionis. Todos os direitos reservados.</div>
        </div>
      </footer>
    </div>
  );
}

/* ---------- FAQ ---------- */
function FAQ() {
  const [open, setOpen] = useState(0);
  const items = [
    { q: "Preciso instalar alguma coisa?", a: "Não. Tudo funciona pelo WhatsApp, pelo seu e-mail e por um portal web. Você só precisa enviar a nota — a IA faz o resto." },
    { q: "Funciona pra MEI E pra CPF na mesma conta?", a: "Sim. O Aionis separa automaticamente o que é CPF e o que é CNPJ, mesmo se você enviar tudo pelo mesmo WhatsApp." },
    { q: "É seguro mandar minhas notas por WhatsApp?", a: "100% seguro. Tudo é criptografado, em conformidade com LGPD e armazenado em servidores brasileiros. Você é o único dono dos seus dados." },
    { q: "E se a IA classificar algo errado?", a: "Você pode revisar e corrigir em um clique. A cada correção, a IA aprende seus padrões e fica ainda mais precisa pra você." },
    { q: "Meu contador consegue usar?", a: "Sim — e ele vai te agradecer. O Aionis exporta tudo no formato esperado por escritórios contábeis e ainda dá acesso de visualização gratuito pro seu contador." },
    { q: "Posso cancelar quando quiser?", a: "Sim. Sem multa, sem fidelidade, sem ligação chata pra cancelar. Tudo dentro do próprio app." },
    { q: "E se eu não gostar?", a: "Você tem 30 dias de garantia incondicional. Não amou? A gente devolve 100% do valor pago. Simples assim." },
  ];
  return (
    <section id="faq" className="bg-white border-t border-border">
      <div className="max-w-4xl mx-auto px-6 py-24">
        <div className="text-center mb-12">
          <div className="text-xs uppercase tracking-[0.18em] text-[#14B88A] mb-3">FAQ</div>
          <h2 className="font-display text-4xl md:text-5xl">Tirando as dúvidas reais.</h2>
        </div>
        <div className="space-y-3">
          {items.map((it, i) => {
            const isOpen = open === i;
            return (
              <div key={i} className={`rounded-[20px] border transition ${isOpen ? "border-[#14B88A] bg-[#E8F4EF]/30" : "border-border bg-white hover:border-[#0E1B2C]/20"}`}>
                <button onClick={() => setOpen(isOpen ? -1 : i)}
                  className="w-full text-left p-5 flex items-center justify-between gap-4">
                  <span className="font-display font-semibold text-[#0E1B2C]">{it.q}</span>
                  <span className={`w-8 h-8 rounded-lg flex items-center justify-center transition ${isOpen ? "bg-[#14B88A] text-white rotate-180" : "bg-[#F5F4EF] text-[#6B7385]"}`}>
                    <ChevronDown size={16}/>
                  </span>
                </button>
                {isOpen && (
                  <div className="px-5 pb-5 text-sm text-[#6B7385] leading-relaxed">
                    {it.a}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Suporte humano */}
        <div className="mt-10 p-6 rounded-[20px] bg-[#0E1B2C] text-white flex items-center justify-between gap-5 flex-wrap">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-[14px] bg-[#14B88A] flex items-center justify-center">
              <MessageCircle size={22}/>
            </div>
            <div>
              <div className="font-display font-semibold">Ainda tem dúvida?</div>
              <div className="text-sm text-white/60">Fala com a gente no WhatsApp — respondemos em minutos.</div>
            </div>
          </div>
          <button className="bg-[#14B88A] hover:bg-[#0ea273] h-11 px-5 rounded-[14px] flex items-center gap-2 text-sm">
            <MessageCircle size={16}/> Chamar no WhatsApp
          </button>
        </div>
      </div>
    </section>
  );
}

/* ---------- Hero mock — phone + dashboard preview ---------- */
function HeroMock() {
  return (
    <div className="relative">
      {/* dashboard card */}
      <div className="bg-white rounded-[20px] border border-border shadow-[0_30px_80px_-30px_rgba(11,26,47,0.25)] p-5">
        <div className="flex items-center justify-between mb-4">
          <div>
            <div className="text-xs text-[#6B7385]">Saldo estimado</div>
            <div className="font-display text-2xl text-[#0E1B2C]">R$ 42.380,15</div>
          </div>
          <div className="text-xs px-2.5 py-1 rounded-full bg-[#E8F4EF] text-[#14B88A] font-semibold">+ 12,4%</div>
        </div>
        <div className="h-32 min-w-0">
          <ResponsiveContainer width="100%" height={128}>
            <AreaChart data={mockFlow}>
              <defs>
                <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#14B88A" stopOpacity={0.45}/>
                  <stop offset="100%" stopColor="#14B88A" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <Area type="monotone" dataKey="v" stroke="#14B88A" strokeWidth={2.4} fill="url(#g1)"/>
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <div className="grid grid-cols-3 gap-2 mt-3 text-center">
          {[
            { l: "Receitas", v: "28,1k", c: "text-[#14B88A]" },
            { l: "Despesas", v: "16,4k", c: "text-[#0E1B2C]" },
            { l: "Pendentes", v: "3", c: "text-[#F59E0B]" },
          ].map((x) => (
            <div key={x.l} className="bg-[#F5F4EF] rounded-lg py-2">
              <div className="text-[10px] text-[#6B7385]">{x.l}</div>
              <div className={`font-mono text-sm ${x.c}`}>{x.v}</div>
            </div>
          ))}
        </div>
      </div>

      {/* whatsapp chat card */}
      <div className="absolute -bottom-10 -left-6 w-64 bg-white rounded-[20px] border border-border shadow-[0_20px_50px_-20px_rgba(11,26,47,0.3)] p-4">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-full bg-[#14B88A] flex items-center justify-center text-white">
            <MessageCircle size={16}/>
          </div>
          <div>
            <div className="text-xs font-semibold">Aionis no WhatsApp</div>
            <div className="text-[10px] text-[#14B88A]">online</div>
          </div>
        </div>
        <div className="space-y-2">
          <div className="bg-[#F5F4EF] text-xs p-2.5 rounded-lg rounded-tl-none w-fit">
            📎 Comprovante_Posto.pdf
          </div>
          <div className="bg-[#E8F4EF] text-xs p-2.5 rounded-lg rounded-tr-none ml-auto w-fit text-[#0E1B2C]">
            ✓ Lançado: <b>R$ 187,40</b><br/>Combustível · Posto Shell
          </div>
        </div>
      </div>

      {/* alert pill */}
      <div className="absolute -top-4 -right-4 bg-white rounded-[14px] border border-border shadow-[0_12px_30px_-10px_rgba(11,26,47,0.2)] px-4 py-3 flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-lg bg-[#F59E0B]/15 text-[#F59E0B] flex items-center justify-center">
          <AlertTriangle size={16}/>
        </div>
        <div>
          <div className="text-xs font-semibold">3 contas vencem sexta</div>
          <div className="text-[10px] text-[#6B7385]">R$ 2.430,00</div>
        </div>
      </div>
    </div>
  );
}

/* ============================================================
   LOGIN
   ============================================================ */
export function Login() {
  const navigate = useNavigate();
  const onLogin = () => { authLogin(); navigate("/onboarding"); };
  const onBack = () => navigate("/");
  const onSignup = () => { authLogin(); navigate("/onboarding"); };
  return (
    <div className="min-h-screen grid lg:grid-cols-2 bg-[#F5F4EF]">
      <div className="hidden lg:flex relative bg-[#0E1B2C] text-white p-12 flex-col justify-between overflow-hidden">
        <div className="absolute inset-0 opacity-40"
             style={{ background: "radial-gradient(circle at 70% 30%, rgba(16,185,129,0.5) 0%, transparent 50%)" }}/>
        <div className="relative">
          <Logo mono/>
        </div>
        <div className="relative">
          <h2 className="font-display text-4xl leading-tight">
            "Em 30 dias, o Aionis tirou minha planilha do caos. Hoje sei quanto sobra no fim do mês."
          </h2>
          <div className="mt-6 flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-[#14B88A]/30"/>
            <div>
              <div className="font-semibold">Camila Andrade</div>
              <div className="text-sm text-white/60">MEI · Estúdio Lume</div>
            </div>
          </div>
        </div>
        <div className="relative text-xs text-white/40">— seu financeiro organizado, inteligente e sem complicação.</div>
      </div>

      <div className="flex items-center justify-center p-6">
        <div className="w-full max-w-md">
          <button onClick={onBack} className="text-sm text-[#6B7385] hover:text-[#0E1B2C] flex items-center gap-1 mb-8">
            <ChevronLeft size={16}/> Voltar
          </button>
          <Logo/>
          <h1 className="font-display text-3xl mt-8">Entrar na sua conta</h1>
          <p className="text-sm text-[#6B7385] mt-2">Acesse seu painel financeiro inteligente.</p>

          <form className="mt-8 space-y-4" onSubmit={(e) => { e.preventDefault(); onLogin(); }}>
            <div>
              <label className="block mb-1.5">E-mail</label>
              <input type="email" defaultValue="camila@estudiolume.com.br"
                className="w-full h-12 px-4 rounded-[14px] border border-border bg-white focus:border-[#14B88A] focus:ring-2 focus:ring-[#14B88A]/20 outline-none transition"/>
            </div>
            <div>
              <div className="flex justify-between mb-1.5">
                <label>Senha</label>
                <a href="#" className="text-xs text-[#14B88A] hover:underline">Esqueci minha senha</a>
              </div>
              <input type="password" defaultValue="••••••••••"
                className="w-full h-12 px-4 rounded-[14px] border border-border bg-white focus:border-[#14B88A] focus:ring-2 focus:ring-[#14B88A]/20 outline-none transition"/>
            </div>
            <button type="submit" className="w-full h-12 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white font-semibold transition">
              Entrar
            </button>
          </form>

          <div className="mt-6 text-center text-sm text-[#6B7385]">
            Ainda não tem conta?{" "}
            <button onClick={onSignup} className="text-[#0E1B2C] font-semibold hover:underline">Criar conta</button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ============================================================
   ONBOARDING
   ============================================================ */
export function Onboarding() {
  const navigate = useNavigate();
  const onDone = () => { authLogin(); navigate("/app/dashboard"); };
  const [step, setStep] = useState(0);
  const [type, setType] = useState<"cpf" | "mei" | "empresa">("mei");

  const steps = ["Tipo de conta", "Seus dados", "Configuração financeira", "Conectar canais"];

  return (
    <div className="min-h-screen bg-[#F5F4EF] flex flex-col">
      <header className="border-b border-border bg-white">
        <div className="max-w-5xl mx-auto px-6 h-16 flex items-center justify-between">
          <Logo/>
          <button onClick={onDone} className="text-sm text-[#6B7385] hover:text-[#0E1B2C]">Pular por agora</button>
        </div>
      </header>

      <div className="max-w-3xl mx-auto px-6 py-10 w-full flex-1">
        {/* Stepper */}
        <div className="flex items-center gap-2 mb-10">
          {steps.map((s, i) => (
            <div key={s} className="flex-1 flex items-center gap-2">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold transition ${
                i < step ? "bg-[#14B88A] text-white" : i === step ? "bg-[#0E1B2C] text-white" : "bg-white border border-border text-[#6B7385]"
              }`}>
                {i < step ? <Check size={14}/> : i + 1}
              </div>
              <div className={`text-xs ${i === step ? "text-[#0E1B2C] font-semibold" : "text-[#6B7385]"}`}>{s}</div>
              {i < steps.length - 1 && <div className="flex-1 h-px bg-border"/>}
            </div>
          ))}
        </div>

        <div className="bg-white rounded-[20px] border border-border p-8">
          {step === 0 && (
            <div>
              <h2 className="font-display text-2xl">Qual é o tipo da sua conta?</h2>
              <p className="text-[#6B7385] text-sm mt-2">Vamos adaptar o Aionis ao seu perfil.</p>
              <div className="grid sm:grid-cols-3 gap-3 mt-6">
                {[
                  { id: "cpf", icon: User, t: "Pessoa Física", d: "Controle pessoal." },
                  { id: "mei", icon: Receipt, t: "MEI", d: "Microempreendedor." },
                  { id: "empresa", icon: Building2, t: "Empresa", d: "ME ou PME." },
                ].map((o: any) => (
                  <button key={o.id} onClick={() => setType(o.id)}
                    className={`text-left p-5 rounded-[14px] border-2 transition ${
                      type === o.id ? "border-[#14B88A] bg-[#E8F4EF]/40" : "border-border hover:border-[#0E1B2C]/30"
                    }`}>
                    <o.icon size={22} className={type === o.id ? "text-[#14B88A]" : "text-[#0E1B2C]"}/>
                    <div className="mt-3 font-display font-semibold">{o.t}</div>
                    <div className="text-xs text-[#6B7385] mt-1">{o.d}</div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 1 && (
            <div>
              <h2 className="font-display text-2xl">Seus dados principais</h2>
              <p className="text-[#6B7385] text-sm mt-2">Para personalizar seu financeiro e canais de envio.</p>
              <div className="grid sm:grid-cols-2 gap-4 mt-6">
                <Field label="Nome completo" v="Camila Andrade"/>
                <Field label={type === "cpf" ? "CPF" : "CNPJ"} v={type === "cpf" ? "123.456.789-00" : "42.318.901/0001-22"}/>
                <Field label="Empresa" v="Estúdio Lume"/>
                <Field label="WhatsApp" v="+55 (11) 98123-4567"/>
                <Field label="E-mail" v="camila@estudiolume.com.br" full/>
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <h2 className="font-display text-2xl">Configuração financeira</h2>
              <p className="text-[#6B7385] text-sm mt-2">Categorias e regras iniciais. Pode editar depois.</p>
              <div className="mt-6 space-y-5">
                <div>
                  <label>Categorias ativas</label>
                  <div className="flex flex-wrap gap-2 mt-2">
                    {["Receita serviços","Receita produtos","Aluguel","Energia","Internet","Combustível","Marketing","Impostos","Fornecedores","Salários"].map((c, i) => (
                      <span key={c} className={`px-3 py-1.5 rounded-full text-xs border ${i < 6 ? "bg-[#0E1B2C] text-white border-[#0E1B2C]" : "border-border text-[#6B7385] hover:border-[#0E1B2C]/40 cursor-pointer"}`}>
                        {i < 6 && "✓ "}{c}
                      </span>
                    ))}
                  </div>
                </div>
                <div className="grid sm:grid-cols-2 gap-4">
                  <Field label="Conta bancária principal" v="Itaú · ag 1234 / 56789-0"/>
                  <Field label="Dia padrão de vencimento" v="10"/>
                </div>
                <div className="bg-[#F5F4EF] rounded-[14px] p-4 flex items-start gap-3">
                  <Bell size={18} className="text-[#14B88A] mt-0.5"/>
                  <div>
                    <div className="font-semibold text-sm">Alertas inteligentes ativados</div>
                    <div className="text-xs text-[#6B7385]">Vencimentos, caixa baixo, gastos fora do padrão e documentos pendentes.</div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <h2 className="font-display text-2xl">Conecte seus canais</h2>
              <p className="text-[#6B7385] text-sm mt-2">Onde o Aionis vai receber seus documentos.</p>
              <div className="mt-6 space-y-3">
                {[
                  { icon: MessageCircle, t: "WhatsApp", d: "+55 (11) 98123-4567", status: "Conectado" },
                  { icon: Mail, t: "E-mail dedicado", d: "lume@notas.aionis.com.br", status: "Conectado" },
                  { icon: Upload, t: "Upload pelo portal", d: "Drag and drop dentro do app", status: "Sempre ativo" },
                ].map((c) => (
                  <div key={c.t} className="flex items-center gap-4 p-4 rounded-[14px] border border-border">
                    <div className="w-11 h-11 rounded-lg bg-[#E8F4EF] text-[#14B88A] flex items-center justify-center">
                      <c.icon size={20}/>
                    </div>
                    <div className="flex-1">
                      <div className="font-display font-semibold">{c.t}</div>
                      <div className="text-xs text-[#6B7385] font-mono">{c.d}</div>
                    </div>
                    <div className="text-xs font-semibold text-[#14B88A] flex items-center gap-1">
                      <CheckCircle2 size={14}/> {c.status}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="flex justify-between mt-10">
            <button
              onClick={() => setStep((s) => Math.max(0, s - 1))}
              disabled={step === 0}
              className="h-11 px-5 rounded-[14px] text-sm text-[#6B7385] hover:text-[#0E1B2C] disabled:opacity-30">
              Voltar
            </button>
            <button
              onClick={() => (step === steps.length - 1 ? onDone() : setStep((s) => s + 1))}
              className="h-11 px-6 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white flex items-center gap-2">
              {step === steps.length - 1 ? "Ir para o painel" : "Continuar"} <ArrowRight size={16}/>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
function Field({ label, v, full }: { label: string; v: string; full?: boolean }) {
  return (
    <div className={full ? "sm:col-span-2" : ""}>
      <label className="block mb-1.5">{label}</label>
      <input defaultValue={v}
        className="w-full h-11 px-4 rounded-[14px] border border-border bg-white focus:border-[#14B88A] focus:ring-2 focus:ring-[#14B88A]/20 outline-none transition"/>
    </div>
  );
}

/* ============================================================
   APP SHELL — sidebar + topbar wrapper
   ============================================================ */
export function AppShell() {
  const navigate = useNavigate();
  return (
    <div className="min-h-screen bg-[#F5F4EF] grid grid-cols-[260px_1fr]">
      <aside className="bg-[#0E1B2C] text-white p-5 flex flex-col gap-1 sticky top-0 h-screen">
        <Link to="/app/dashboard" className="px-2 mb-6">
          <Logo mono/>
        </Link>
        <div className="text-[10px] uppercase tracking-wider text-white/40 px-3 mb-2">Navegação</div>
        {screens.map((s) => (
          <NavLink key={s.path} to={s.path}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 h-10 rounded-lg text-sm transition ${
                isActive ? "bg-[#14B88A] text-white" : "text-white/70 hover:bg-white/5 hover:text-white"
              }`
            }>
            <s.icon size={17}/> {s.label}
          </NavLink>
        ))}
        <div className="mt-auto">
          <div className="rounded-[14px] bg-white/5 p-4 border border-white/5">
            <div className="flex items-center gap-2 text-xs text-[#14B88A] font-semibold">
              <Sparkles size={14}/> Plano MEI
            </div>
            <div className="text-xs text-white/60 mt-1">312 / 500 documentos</div>
            <div className="h-1.5 bg-white/10 rounded-full mt-2 overflow-hidden">
              <div className="h-full bg-[#14B88A] rounded-full" style={{ width: "62%" }}/>
            </div>
            <button className="mt-3 w-full text-xs h-8 rounded-lg bg-[#14B88A] hover:bg-[#0ea273]">
              Fazer upgrade
            </button>
          </div>
          <button onClick={() => { authLogout(); navigate("/"); }} className="mt-3 flex items-center gap-2 text-xs text-white/50 hover:text-white px-3">
            <LogOut size={14}/> Sair
          </button>
        </div>
      </aside>

      <main>
        <Topbar/>
        <div className="p-8">
          <Outlet/>
        </div>
      </main>
    </div>
  );
}

function Topbar() {
  const loc = useLocation();
  const title = screens.find((s) => loc.pathname.startsWith(s.path))?.label ?? "Aionis";
  return (
    <header className="h-16 bg-white border-b border-border px-8 flex items-center justify-between sticky top-0 z-30">
      <div>
        <div className="text-xs text-[#6B7385]">Estúdio Lume · MEI</div>
        <div className="font-display font-semibold text-[#0E1B2C]">{title}</div>
      </div>
      <div className="flex items-center gap-4">
        <div className="relative">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7385]"/>
          <input placeholder="Buscar fornecedor, documento, valor…"
            className="h-10 w-80 pl-9 pr-4 rounded-[14px] bg-[#F5F4EF] border border-transparent focus:border-[#14B88A] outline-none text-sm transition"/>
        </div>
        <button className="relative w-10 h-10 rounded-[14px] bg-[#F5F4EF] flex items-center justify-center hover:bg-[#E8F4EF] transition">
          <Bell size={16}/>
          <span className="absolute top-2 right-2 w-2 h-2 rounded-full bg-[#14B88A]"/>
        </button>
        <div className="flex items-center gap-3 pl-3 border-l border-border">
          <div className="w-9 h-9 rounded-full bg-gradient-to-br from-[#14B88A] to-[#0E1B2C] flex items-center justify-center text-white text-xs font-semibold">CA</div>
          <div className="text-sm">
            <div className="font-semibold leading-tight">Camila A.</div>
            <div className="text-xs text-[#6B7385] leading-tight">Admin</div>
          </div>
        </div>
      </div>
    </header>
  );
}

/* ============================================================
   DASHBOARD
   ============================================================ */
export function Dashboard() {
  return (
    <div className="space-y-6">
      {/* KPI cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Kpi label="Saldo estimado" value="R$ 42.380,15" delta="+12,4%" trend="up" icon={Wallet}/>
        <Kpi label="Receitas do mês" value="R$ 28.140,00" delta="+8,1%" trend="up" icon={ArrowUpRight}/>
        <Kpi label="Despesas do mês" value="R$ 16.420,80" delta="-3,2%" trend="down" icon={ArrowDownRight}/>
        <Kpi label="Lucro estimado" value="R$ 11.719,20" delta="+15,7%" trend="up" icon={TrendingUp} highlight/>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MiniCard label="Contas a pagar" value="R$ 5.840,00" sub="12 contas em aberto" icon={CreditCard} color="text-[#0E1B2C]"/>
        <MiniCard label="Contas vencidas" value="R$ 1.230,00" sub="2 contas atrasadas" icon={AlertTriangle} color="text-[#DC2657]"/>
        <MiniCard label="Documentos pendentes" value="7" sub="aguardando revisão" icon={FileText} color="text-[#F59E0B]"/>
        <MiniCard label="Saúde financeira" value="84/100" sub="boa, com atenção" icon={Heart} color="text-[#14B88A]"/>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <ChartCard title="Fluxo de caixa · 30 dias" className="lg:col-span-2">
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={mockFlow30}>
              <defs>
                <linearGradient id="grad-rec" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#14B88A" stopOpacity={0.35}/>
                  <stop offset="100%" stopColor="#14B88A" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="grad-desp" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#0E1B2C" stopOpacity={0.25}/>
                  <stop offset="100%" stopColor="#0E1B2C" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#EEF1F6" vertical={false}/>
              <XAxis dataKey="d" tick={{ fontSize: 11, fill: "#6B7385" }} axisLine={false} tickLine={false}/>
              <YAxis tick={{ fontSize: 11, fill: "#6B7385" }} axisLine={false} tickLine={false}/>
              <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #EEF1F6" }}/>
              <Area type="monotone" dataKey="rec" stroke="#14B88A" strokeWidth={2.4} fill="url(#grad-rec)"/>
              <Area type="monotone" dataKey="desp" stroke="#0E1B2C" strokeWidth={2.4} fill="url(#grad-desp)"/>
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Despesas por categoria">
          <ResponsiveContainer width="100%" height={260}>
            <PieChart>
              <Pie data={mockCats} dataKey="v" nameKey="n" innerRadius={55} outerRadius={90} paddingAngle={3}>
                {mockCats.map((_, i) => <Cell key={i} fill={["#14B88A","#0E1B2C","#38BDF8","#F59E0B","#8B5CF6"][i]}/>)}
              </Pie>
              <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #EEF1F6" }}/>
            </PieChart>
          </ResponsiveContainer>
          <div className="space-y-2 mt-2">
            {mockCats.map((c, i) => (
              <div key={c.n} className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-sm" style={{ background: ["#14B88A","#0E1B2C","#38BDF8","#F59E0B","#8B5CF6"][i] }}/>
                  {c.n}
                </div>
                <div className="font-mono text-[#6B7385]">R$ {c.v.toLocaleString("pt-BR")}</div>
              </div>
            ))}
          </div>
        </ChartCard>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <ChartCard title="Receitas × Despesas" className="lg:col-span-2">
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={mockRD} barCategoryGap={18}>
              <CartesianGrid strokeDasharray="3 3" stroke="#EEF1F6" vertical={false}/>
              <XAxis dataKey="m" tick={{ fontSize: 11, fill: "#6B7385" }} axisLine={false} tickLine={false}/>
              <YAxis tick={{ fontSize: 11, fill: "#6B7385" }} axisLine={false} tickLine={false}/>
              <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #EEF1F6" }}/>
              <Bar dataKey="rec" fill="#14B88A" radius={[6,6,0,0]}/>
              <Bar dataKey="desp" fill="#0E1B2C" radius={[6,6,0,0]}/>
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Top fornecedores">
          <div className="space-y-3">
            {[
              { n: "Posto Shell BR", v: 1840, p: 78 },
              { n: "Aluguel Sala 402", v: 1500, p: 64 },
              { n: "Vivo Empresarial", v: 489, p: 21 },
              { n: "Adobe Creative", v: 287, p: 12 },
              { n: "iFood Pro", v: 234, p: 10 },
            ].map((f) => (
              <div key={f.n}>
                <div className="flex justify-between text-xs mb-1.5">
                  <span className="font-semibold text-[#0E1B2C]">{f.n}</span>
                  <span className="font-mono text-[#6B7385]">R$ {f.v.toLocaleString("pt-BR")}</span>
                </div>
                <div className="h-1.5 bg-[#F5F4EF] rounded-full">
                  <div className="h-full bg-gradient-to-r from-[#14B88A] to-[#0E1B2C] rounded-full" style={{ width: `${f.p}%` }}/>
                </div>
              </div>
            ))}
          </div>
        </ChartCard>
      </div>

      {/* Alerts */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-display">Alertas inteligentes</h2>
          <button className="text-sm text-[#14B88A] flex items-center gap-1 hover:underline">Ver todos <ChevronRight size={14}/></button>
        </div>
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <Alert tone="warn" icon={TrendingDown} title="Seu caixa pode ficar negativo em 12 dias." body="Considere antecipar recebíveis de R$ 4.200,00."/>
          <Alert tone="info" icon={Calendar} title="R$ 2.430,00 vencem até sexta-feira." body="4 contas distribuídas em 3 fornecedores."/>
          <Alert tone="danger" icon={TrendingUp} title="Combustível subiu 28% este mês." body="Maior que sua média dos últimos 3 meses."/>
          <Alert tone="warn" icon={Paperclip} title="5 pagamentos sem comprovante." body="Anexe para manter sua conformidade fiscal."/>
        </div>
      </div>
    </div>
  );
}

function Kpi({ label, value, delta, trend, icon: Icon, highlight }: any) {
  return (
    <div className={`rounded-[20px] p-5 border ${highlight ? "bg-[#0E1B2C] text-white border-[#0E1B2C]" : "bg-white border-border"}`}>
      <div className="flex items-center justify-between">
        <div className={`text-xs ${highlight ? "text-white/60" : "text-[#6B7385]"}`}>{label}</div>
        <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${highlight ? "bg-[#14B88A]/20 text-[#14B88A]" : "bg-[#E8F4EF] text-[#14B88A]"}`}>
          <Icon size={16}/>
        </div>
      </div>
      <div className="font-display text-2xl mt-3">{value}</div>
      <div className={`text-xs mt-1 flex items-center gap-1 ${trend === "up" ? "text-[#14B88A]" : "text-[#DC2657]"}`}>
        {trend === "up" ? <ArrowUpRight size={12}/> : <ArrowDownRight size={12}/>} {delta}
        <span className={highlight ? "text-white/40" : "text-[#6B7385]"}>vs. mês anterior</span>
      </div>
    </div>
  );
}
function MiniCard({ label, value, sub, icon: Icon, color }: any) {
  return (
    <div className="bg-white rounded-[20px] p-5 border border-border flex items-center gap-4">
      <div className={`w-11 h-11 rounded-[14px] bg-[#F5F4EF] flex items-center justify-center ${color}`}>
        <Icon size={20}/>
      </div>
      <div>
        <div className="text-xs text-[#6B7385]">{label}</div>
        <div className="font-display text-xl">{value}</div>
        <div className="text-xs text-[#6B7385]">{sub}</div>
      </div>
    </div>
  );
}
function ChartCard({ title, children, className = "" }: any) {
  return (
    <div className={`bg-white rounded-[20px] border border-border p-6 ${className}`}>
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-display">{title}</h3>
        <button className="text-xs text-[#6B7385] hover:text-[#0E1B2C] flex items-center gap-1">
          Últimos 30 dias <ChevronDown size={12}/>
        </button>
      </div>
      {children}
    </div>
  );
}
function Alert({ tone, icon: Icon, title, body }: any) {
  const tones: any = {
    warn: { bg: "bg-[#FAF1DD]", text: "text-[#B26B00]", icon: "bg-[#F59E0B]/15 text-[#F59E0B]" },
    danger: { bg: "bg-[#FBEBEE]", text: "text-[#9F1239]", icon: "bg-[#DC2657]/15 text-[#DC2657]" },
    info: { bg: "bg-[#E8F4EF]", text: "text-[#04221A]", icon: "bg-[#14B88A]/15 text-[#14B88A]" },
  };
  const t = tones[tone];
  return (
    <div className={`${t.bg} rounded-[20px] p-5 border border-transparent`}>
      <div className={`w-9 h-9 rounded-lg ${t.icon} flex items-center justify-center mb-3`}>
        <Icon size={16}/>
      </div>
      <div className={`font-display font-semibold text-sm ${t.text}`}>{title}</div>
      <div className="text-xs text-[#6B7385] mt-1">{body}</div>
    </div>
  );
}

/* ============================================================
   DOCUMENTS
   ============================================================ */
const docsData = [
  { d: "21/05", o: "WhatsApp", t: "NF-e", v: "R$ 1.840,00", f: "Posto Shell BR", s: 96, st: "Lançado" },
  { d: "21/05", o: "E-mail", t: "Boleto", v: "R$ 1.500,00", f: "Imobiliária Vértice", s: 92, st: "Lançado" },
  { d: "20/05", o: "Portal", t: "Cupom", v: "R$ 84,30", f: "Mercado Pago", s: 71, st: "Pendente" },
  { d: "20/05", o: "WhatsApp", t: "NF-e", v: "R$ 489,90", f: "Vivo Empresarial", s: 88, st: "Lançado" },
  { d: "20/05", o: "WhatsApp", t: "Comprovante", v: "R$ 287,00", f: "Adobe Creative", s: 64, st: "Processando" },
  { d: "19/05", o: "E-mail", t: "NF-e", v: "R$ 3.200,00", f: "Cliente · Studio M", s: 99, st: "Lançado" },
  { d: "19/05", o: "Portal", t: "Recibo", v: "R$ 120,00", f: "?", s: 32, st: "Erro" },
  { d: "18/05", o: "WhatsApp", t: "Cupom", v: "R$ 56,40", f: "iFood Pro", s: 84, st: "Recebido" },
];

export function Documents() {
  const [filter, setFilter] = useState("Todos");
  const filters = ["Todos","Recebido","Processando","Pendente","Lançado","Erro"];
  const filtered = filter === "Todos" ? docsData : docsData.filter((d) => d.st === filter);
  const [selected, setSelected] = useState<typeof docsData[0] | null>(docsData[2]);

  return (
    <div className="grid grid-cols-1 xl:grid-cols-[1fr_420px] gap-6">
      <div className="space-y-6">
        {/* Upload zone */}
        <div className="bg-white rounded-[20px] border border-border p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="font-display">Documentos</h2>
              <p className="text-sm text-[#6B7385]">Envie notas, comprovantes ou boletos — a IA cuida do resto.</p>
            </div>
            <button className="h-10 px-4 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white flex items-center gap-2 text-sm">
              <Plus size={16}/> Enviar documento
            </button>
          </div>
          <div className="border-2 border-dashed border-border rounded-[14px] p-8 text-center hover:border-[#14B88A] hover:bg-[#E8F4EF]/30 transition cursor-pointer">
            <div className="w-12 h-12 rounded-[14px] bg-[#E8F4EF] text-[#14B88A] flex items-center justify-center mx-auto mb-3">
              <Upload size={20}/>
            </div>
            <div className="font-semibold">Arraste arquivos ou clique para enviar</div>
            <div className="text-xs text-[#6B7385] mt-1">PDF, JPG, PNG, XML · ou envie pelo WhatsApp (+55 11 98123-4567)</div>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-white rounded-[20px] border border-border">
          <div className="flex items-center gap-2 p-4 border-b border-border overflow-x-auto">
            {filters.map((f) => (
              <button key={f} onClick={() => setFilter(f)}
                className={`px-3 h-8 rounded-lg text-xs whitespace-nowrap transition ${
                  filter === f ? "bg-[#0E1B2C] text-white" : "text-[#6B7385] hover:bg-[#F5F4EF]"
                }`}>{f}</button>
            ))}
            <div className="ml-auto flex items-center gap-2">
              <button className="px-3 h-8 rounded-lg text-xs text-[#6B7385] hover:bg-[#F5F4EF] flex items-center gap-1.5"><Filter size={12}/> Filtros</button>
              <button className="px-3 h-8 rounded-lg text-xs text-[#6B7385] hover:bg-[#F5F4EF] flex items-center gap-1.5"><Download size={12}/> Exportar</button>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs uppercase tracking-wider text-[#6B7385] border-b border-border">
                  <th className="px-5 py-3">Data</th>
                  <th className="px-5 py-3">Origem</th>
                  <th className="px-5 py-3">Tipo</th>
                  <th className="px-5 py-3">Valor</th>
                  <th className="px-5 py-3">Fornecedor</th>
                  <th className="px-5 py-3">Score IA</th>
                  <th className="px-5 py-3">Status</th>
                  <th className="px-5 py-3"></th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((d, i) => (
                  <tr key={i} className={`border-b border-border hover:bg-[#F5F4EF]/60 transition cursor-pointer ${selected === d ? "bg-[#E8F4EF]/40" : ""}`}
                      onClick={() => setSelected(d)}>
                    <td className="px-5 py-3.5 font-mono text-xs text-[#6B7385]">{d.d}</td>
                    <td className="px-5 py-3.5">{d.o}</td>
                    <td className="px-5 py-3.5">{d.t}</td>
                    <td className="px-5 py-3.5 font-mono">{d.v}</td>
                    <td className="px-5 py-3.5">{d.f}</td>
                    <td className="px-5 py-3.5"><ScoreBadge score={d.s}/></td>
                    <td className="px-5 py-3.5"><StatusBadge status={d.st}/></td>
                    <td className="px-5 py-3.5 text-right">
                      <button className="text-xs text-[#14B88A] hover:underline flex items-center gap-1 ml-auto"><Eye size={12}/> Revisar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Side review panel */}
      {selected && (
        <aside className="bg-white rounded-[20px] border border-border p-6 h-fit sticky top-24">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display">Revisão da IA</h3>
            <span className="text-xs px-2 py-1 rounded-full bg-[#E8F4EF] text-[#14B88A] font-semibold">Score {selected.s}%</span>
          </div>
          <div className="aspect-[4/5] rounded-[14px] bg-gradient-to-br from-[#F5F4EF] to-white border border-border flex flex-col items-center justify-center p-6 mb-5">
            <FileText size={40} className="text-[#0E1B2C]/30 mb-3"/>
            <div className="text-xs font-mono text-[#6B7385]">{selected.t.toLowerCase()}_{selected.d.replace("/","")}.pdf</div>
            <div className="mt-4 px-3 py-1.5 rounded-full bg-[#0E1B2C] text-white text-[10px] uppercase tracking-wider">Preview do documento</div>
          </div>
          <div className="space-y-3">
            <Row k="Valor" v={selected.v}/>
            <Row k="Data" v={`${selected.d}/2026`}/>
            <Row k="Fornecedor" v={selected.f}/>
            <Row k="Categoria sugerida" v={<span className="px-2 py-0.5 rounded-full bg-[#E8F4EF] text-[#14B88A] text-xs">Combustível</span>}/>
            <Row k="Origem" v={selected.o}/>
          </div>
          <div className="grid grid-cols-3 gap-2 mt-6">
            <button className="h-10 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white text-xs">Confirmar</button>
            <button className="h-10 rounded-[14px] bg-[#F5F4EF] hover:bg-[#E8F4EF] text-[#0E1B2C] text-xs">Corrigir</button>
            <button className="h-10 rounded-[14px] bg-[#F5F4EF] hover:bg-[#FBEBEE] text-[#0E1B2C] hover:text-[#DC2657] text-xs">Ignorar</button>
          </div>
        </aside>
      )}
    </div>
  );
}
function Row({ k, v }: { k: string; v: any }) {
  return (
    <div className="flex items-center justify-between text-sm py-2 border-b border-border last:border-0">
      <span className="text-[#6B7385]">{k}</span>
      <span className="font-medium text-[#0E1B2C]">{v}</span>
    </div>
  );
}
function ScoreBadge({ score }: { score: number }) {
  const color = score >= 85 ? "text-[#14B88A] bg-[#E8F4EF]" : score >= 60 ? "text-[#F59E0B] bg-[#FAF1DD]" : "text-[#DC2657] bg-[#FBEBEE]";
  return <span className={`px-2 py-1 rounded-md font-mono text-xs ${color}`}>{score}%</span>;
}
function StatusBadge({ status }: { status: string }) {
  const map: any = {
    Lançado: { c: "text-[#14B88A] bg-[#E8F4EF]", i: CheckCircle2 },
    Processando: { c: "text-[#38BDF8] bg-[#E0F2FE]", i: RotateCcw },
    Pendente: { c: "text-[#F59E0B] bg-[#FAF1DD]", i: Clock },
    Recebido: { c: "text-[#6B7385] bg-[#F5F4EF]", i: Eye },
    Erro: { c: "text-[#DC2657] bg-[#FBEBEE]", i: XCircle },
    Pago: { c: "text-[#14B88A] bg-[#E8F4EF]", i: CheckCircle2 },
    Aberto: { c: "text-[#6B7385] bg-[#F5F4EF]", i: Clock },
    Vencido: { c: "text-[#DC2657] bg-[#FBEBEE]", i: AlertTriangle },
    Cancelado: { c: "text-[#6B7385] bg-[#F5F4EF]", i: XCircle },
  };
  const m = map[status] || map.Aberto;
  const I = m.i;
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-md text-xs font-medium ${m.c}`}>
      <I size={11}/> {status}
    </span>
  );
}

/* ============================================================
   ENTRIES
   ============================================================ */
const entriesData = [
  { d: "21/05", t: "Pagamento posto Shell", c: "Combustível", f: "Posto Shell BR", v: -1840, s: "Lançado", doc: true },
  { d: "21/05", t: "Aluguel sala 402", c: "Aluguel", f: "Imobiliária Vértice", v: -1500, s: "Lançado", doc: true },
  { d: "20/05", t: "Recebimento projeto Lume X", c: "Receita serviços", f: "Studio M", v: 3200, s: "Lançado", doc: true },
  { d: "20/05", t: "Conta de internet", c: "Internet", f: "Vivo Empresarial", v: -489.9, s: "Lançado", doc: true },
  { d: "19/05", t: "Adobe Creative Cloud", c: "Software", f: "Adobe", v: -287, s: "Pendente", doc: false },
  { d: "18/05", t: "Recebimento NF 2351", c: "Receita serviços", f: "Cliente · Verbo Ag.", v: 4800, s: "Lançado", doc: true },
  { d: "17/05", t: "Almoço cliente", c: "Alimentação", f: "iFood Pro", v: -56.4, s: "Lançado", doc: true },
];

export function Entries() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MiniCard label="Receitas" value="R$ 28.140,00" sub="14 lançamentos" icon={ArrowUpRight} color="text-[#14B88A]"/>
        <MiniCard label="Despesas" value="R$ 16.420,80" sub="32 lançamentos" icon={ArrowDownRight} color="text-[#0E1B2C]"/>
        <MiniCard label="Saldo" value="R$ 11.719,20" sub="resultado positivo" icon={Wallet} color="text-[#14B88A]"/>
        <MiniCard label="Pendências" value="3" sub="aguardam revisão" icon={Clock} color="text-[#F59E0B]"/>
      </div>

      <div className="bg-white rounded-[20px] border border-border">
        <div className="flex items-center gap-2 p-4 border-b border-border flex-wrap">
          <FilterPill>Maio 2026</FilterPill>
          <FilterPill>Todas categorias</FilterPill>
          <FilterPill>Todos status</FilterPill>
          <FilterPill>Todas origens</FilterPill>
          <div className="ml-auto flex items-center gap-2">
            <button className="h-10 px-4 rounded-[14px] bg-[#F5F4EF] hover:bg-[#E8F4EF] text-sm flex items-center gap-1.5"><Download size={14}/> Exportar</button>
            <button className="h-10 px-4 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white text-sm flex items-center gap-1.5"><Plus size={14}/> Novo lançamento</button>
          </div>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-wider text-[#6B7385] border-b border-border">
              <th className="px-5 py-3">Data</th>
              <th className="px-5 py-3">Descrição</th>
              <th className="px-5 py-3">Categoria</th>
              <th className="px-5 py-3">Fornecedor / Cliente</th>
              <th className="px-5 py-3 text-right">Valor</th>
              <th className="px-5 py-3">Status</th>
              <th className="px-5 py-3">Doc</th>
            </tr>
          </thead>
          <tbody>
            {entriesData.map((e, i) => (
              <tr key={i} className="border-b border-border hover:bg-[#F5F4EF]/60 transition">
                <td className="px-5 py-3.5 font-mono text-xs text-[#6B7385]">{e.d}</td>
                <td className="px-5 py-3.5 font-medium">{e.t}</td>
                <td className="px-5 py-3.5">
                  <span className="px-2 py-1 rounded-md bg-[#F5F4EF] text-xs text-[#6B7385]">{e.c}</span>
                </td>
                <td className="px-5 py-3.5 text-[#6B7385]">{e.f}</td>
                <td className={`px-5 py-3.5 text-right font-mono font-semibold ${e.v > 0 ? "text-[#14B88A]" : "text-[#0E1B2C]"}`}>
                  {e.v > 0 ? "+" : "−"} R$ {Math.abs(e.v).toLocaleString("pt-BR", { minimumFractionDigits: 2 })}
                </td>
                <td className="px-5 py-3.5"><StatusBadge status={e.s}/></td>
                <td className="px-5 py-3.5">
                  {e.doc
                    ? <Paperclip size={14} className="text-[#14B88A]"/>
                    : <span className="text-xs text-[#DC2657]">faltando</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
function FilterPill({ children }: any) {
  return (
    <button className="h-9 px-3 rounded-lg bg-[#F5F4EF] hover:bg-[#E8F4EF] text-xs text-[#0E1B2C] flex items-center gap-1.5">
      {children} <ChevronDown size={12}/>
    </button>
  );
}

/* ============================================================
   BILLING — contas a pagar / receber
   ============================================================ */
export function Billing() {
  const [tab, setTab] = useState<"pay" | "receive">("pay");
  const pay = [
    { d: "23/05", f: "Imobiliária Vértice", desc: "Aluguel sala 402", v: 1500, s: "Aberto" },
    { d: "24/05", f: "Vivo Empresarial", desc: "Internet 500mb", v: 489.9, s: "Aberto" },
    { d: "20/05", f: "Enel", desc: "Energia · maio", v: 312.5, s: "Vencido" },
    { d: "25/05", f: "Posto Shell BR", desc: "Combustível", v: 440, s: "Aberto" },
    { d: "18/05", f: "Adobe", desc: "Creative Cloud", v: 287, s: "Pago" },
    { d: "30/05", f: "Receita Federal", desc: "DAS MEI", v: 71.6, s: "Aberto" },
  ];
  const receive = [
    { d: "22/05", f: "Studio M", desc: "Projeto Lume X · parcela 2/3", v: 3200, s: "Aberto" },
    { d: "28/05", f: "Verbo Agência", desc: "NF 2351", v: 4800, s: "Aberto" },
    { d: "15/05", f: "Cliente · Norte", desc: "Identidade visual", v: 2100, s: "Pago" },
    { d: "10/05", f: "Cliente · Mira", desc: "Consultoria", v: 950, s: "Vencido" },
  ];
  const list = tab === "pay" ? pay : receive;

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-[20px] border border-border p-2 inline-flex">
        {[
          { id: "pay", l: "Contas a pagar" },
          { id: "receive", l: "Contas a receber" },
        ].map((t) => (
          <button key={t.id} onClick={() => setTab(t.id as any)}
            className={`px-5 h-10 rounded-[14px] text-sm font-semibold transition ${
              tab === t.id ? "bg-[#0E1B2C] text-white" : "text-[#6B7385] hover:text-[#0E1B2C]"
            }`}>
            {t.l}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <MiniCard label="Total em aberto" value={`R$ ${list.filter(x=>x.s==="Aberto").reduce((a,x)=>a+x.v,0).toLocaleString("pt-BR",{minimumFractionDigits:2})}`} sub={`${list.filter(x=>x.s==="Aberto").length} contas`} icon={Banknote} color="text-[#0E1B2C]"/>
        <MiniCard label="Total vencido" value={`R$ ${list.filter(x=>x.s==="Vencido").reduce((a,x)=>a+x.v,0).toLocaleString("pt-BR",{minimumFractionDigits:2})}`} sub={`${list.filter(x=>x.s==="Vencido").length} em atraso`} icon={AlertTriangle} color="text-[#DC2657]"/>
        <MiniCard label="Próximos 7 dias" value={`R$ ${list.slice(0,3).reduce((a,x)=>a+x.v,0).toLocaleString("pt-BR",{minimumFractionDigits:2})}`} sub="agenda da semana" icon={Calendar} color="text-[#14B88A]"/>
      </div>

      <div className="bg-white rounded-[20px] border border-border">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-wider text-[#6B7385] border-b border-border">
              <th className="px-5 py-3">Vencimento</th>
              <th className="px-5 py-3">{tab === "pay" ? "Fornecedor" : "Cliente"}</th>
              <th className="px-5 py-3">Descrição</th>
              <th className="px-5 py-3 text-right">Valor</th>
              <th className="px-5 py-3">Status</th>
              <th className="px-5 py-3 text-right">Ações</th>
            </tr>
          </thead>
          <tbody>
            {list.map((c, i) => (
              <tr key={i} className="border-b border-border hover:bg-[#F5F4EF]/60 transition">
                <td className="px-5 py-3.5 font-mono text-xs">{c.d}/2026</td>
                <td className="px-5 py-3.5 font-medium">{c.f}</td>
                <td className="px-5 py-3.5 text-[#6B7385]">{c.desc}</td>
                <td className="px-5 py-3.5 text-right font-mono font-semibold">R$ {c.v.toLocaleString("pt-BR",{minimumFractionDigits:2})}</td>
                <td className="px-5 py-3.5"><StatusBadge status={c.s}/></td>
                <td className="px-5 py-3.5">
                  <div className="flex items-center justify-end gap-1">
                    <button title="Marcar como pago" className="w-8 h-8 rounded-lg hover:bg-[#E8F4EF] hover:text-[#14B88A] text-[#6B7385] flex items-center justify-center"><CheckCircle2 size={14}/></button>
                    <button title="Anexar comprovante" className="w-8 h-8 rounded-lg hover:bg-[#F5F4EF] text-[#6B7385] flex items-center justify-center"><Paperclip size={14}/></button>
                    <button title="Editar vencimento" className="w-8 h-8 rounded-lg hover:bg-[#F5F4EF] text-[#6B7385] flex items-center justify-center"><Calendar size={14}/></button>
                    <button title="Criar recorrência" className="w-8 h-8 rounded-lg hover:bg-[#F5F4EF] text-[#6B7385] flex items-center justify-center"><RotateCcw size={14}/></button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/* ============================================================
   ASSISTANT (chat)
   ============================================================ */
const suggestions = [
  "Quanto tenho para pagar essa semana?",
  "Qual foi meu maior gasto do mês?",
  "Meu caixa está saudável?",
  "Liste pagamentos sem nota.",
  "Quanto gastei com combustível?",
  "Gerar resumo financeiro do mês.",
];

export function Assistant() {
  const [msgs, setMsgs] = useState<{ who: "u" | "ai"; text: string; card?: any }[]>([
    { who: "ai", text: "Oi, Camila! Sou seu assistente Aionis. Posso responder sobre seu fluxo, vencimentos, KPIs e mais. Pergunte ou escolha uma sugestão abaixo." },
  ]);
  const [input, setInput] = useState("");

  const ask = (q: string) => {
    setMsgs((m) => [...m, { who: "u", text: q }]);
    setInput("");
    setTimeout(() => {
      setMsgs((m) => [...m, makeAnswer(q)]);
    }, 400);
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6">
      <div className="bg-white rounded-[20px] border border-border flex flex-col h-[calc(100vh-180px)]">
        <div className="p-5 border-b border-border flex items-center gap-3">
          <div className="w-10 h-10 rounded-[14px] bg-gradient-to-br from-[#14B88A] to-[#0E1B2C] flex items-center justify-center text-white">
            <Sparkles size={18}/>
          </div>
          <div>
            <div className="font-display font-semibold">Assistente Aionis</div>
            <div className="text-xs text-[#14B88A] flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-[#14B88A] animate-pulse"/> Online · IA financeira
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          {msgs.map((m, i) => (
            <div key={i} className={`flex gap-3 ${m.who === "u" ? "justify-end" : ""}`}>
              {m.who === "ai" && (
                <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#14B88A] to-[#0E1B2C] flex items-center justify-center text-white shrink-0">
                  <Sparkles size={14}/>
                </div>
              )}
              <div className={`max-w-[75%] ${m.who === "u" ? "" : ""}`}>
                <div className={`rounded-[20px] p-4 text-sm leading-relaxed ${
                  m.who === "u"
                    ? "bg-[#0E1B2C] text-white rounded-tr-sm"
                    : "bg-[#F5F4EF] text-[#0E1B2C] rounded-tl-sm"
                }`}>
                  {m.text}
                </div>
                {m.card}
              </div>
              {m.who === "u" && (
                <div className="w-8 h-8 rounded-lg bg-[#0E1B2C] text-white flex items-center justify-center shrink-0 text-xs font-semibold">CA</div>
              )}
            </div>
          ))}
        </div>

        <div className="p-4 border-t border-border">
          <div className="flex gap-2 mb-3 overflow-x-auto">
            {suggestions.slice(0,4).map((s) => (
              <button key={s} onClick={() => ask(s)} className="text-xs whitespace-nowrap px-3 h-8 rounded-lg bg-[#F5F4EF] hover:bg-[#E8F4EF] text-[#0E1B2C]">
                {s}
              </button>
            ))}
          </div>
          <form onSubmit={(e) => { e.preventDefault(); if (input.trim()) ask(input); }}
            className="flex items-center gap-2 bg-[#F5F4EF] rounded-[14px] pr-2">
            <input value={input} onChange={(e) => setInput(e.target.value)}
              placeholder="Pergunte sobre suas finanças…"
              className="flex-1 bg-transparent h-12 px-4 outline-none text-sm"/>
            <button type="submit" className="w-9 h-9 rounded-lg bg-[#14B88A] hover:bg-[#0ea273] text-white flex items-center justify-center">
              <Send size={16}/>
            </button>
          </form>
        </div>
      </div>

      <aside className="space-y-4">
        <div className="bg-white rounded-[20px] border border-border p-5">
          <h3 className="font-display mb-3">Sugestões</h3>
          <div className="space-y-2">
            {suggestions.map((s) => (
              <button key={s} onClick={() => ask(s)}
                className="w-full text-left px-3 py-2.5 rounded-lg text-sm bg-[#F5F4EF] hover:bg-[#E8F4EF] hover:text-[#14B88A] transition">
                {s}
              </button>
            ))}
          </div>
        </div>
        <div className="bg-[#0E1B2C] text-white rounded-[20px] p-5">
          <Sparkles size={20} className="text-[#14B88A] mb-2"/>
          <div className="font-display">IA contextual</div>
          <p className="text-xs text-white/60 mt-2">Suas respostas usam dados reais do seu Aionis. Nada de adivinhação.</p>
        </div>
      </aside>
    </div>
  );
}

function makeAnswer(q: string): { who: "ai"; text: string; card?: any } {
  if (q.toLowerCase().includes("semana") || q.toLowerCase().includes("pagar")) {
    return {
      who: "ai",
      text: "Você tem 4 contas vencendo nos próximos 7 dias, somando R$ 2.741,90.",
      card: (
        <div className="mt-3 bg-white border border-border rounded-[14px] p-4 space-y-2">
          {[
            { d: "23/05", f: "Imobiliária Vértice", v: "R$ 1.500,00" },
            { d: "24/05", f: "Vivo Empresarial", v: "R$ 489,90" },
            { d: "25/05", f: "Posto Shell BR", v: "R$ 440,00" },
            { d: "30/05", f: "Receita Federal · DAS", v: "R$ 71,60" },
          ].map((c) => (
            <div key={c.d} className="flex items-center justify-between text-xs py-1.5 border-b border-border last:border-0">
              <div className="flex items-center gap-3"><span className="font-mono text-[#6B7385]">{c.d}</span>{c.f}</div>
              <span className="font-mono font-semibold">{c.v}</span>
            </div>
          ))}
        </div>
      ),
    };
  }
  if (q.toLowerCase().includes("caixa") || q.toLowerCase().includes("saud")) {
    return {
      who: "ai",
      text: "Sua saúde financeira está em 84/100. Boa, mas com aumento nos custos fixos.",
      card: (
        <div className="mt-3 grid grid-cols-3 gap-2">
          {[
            { l: "Score", v: "84", c: "text-[#14B88A]" },
            { l: "Margem", v: "41%", c: "text-[#0E1B2C]" },
            { l: "Risco caixa", v: "Baixo", c: "text-[#14B88A]" },
          ].map((x) => (
            <div key={x.l} className="bg-white border border-border rounded-[14px] p-3 text-center">
              <div className="text-[10px] text-[#6B7385]">{x.l}</div>
              <div className={`font-display text-lg ${x.c}`}>{x.v}</div>
            </div>
          ))}
        </div>
      ),
    };
  }
  if (q.toLowerCase().includes("combust")) {
    return {
      who: "ai",
      text: "Você gastou R$ 1.840,00 com combustível em maio — 28% acima da sua média trimestral (R$ 1.437,50).",
    };
  }
  return { who: "ai", text: "Analisando seus dados… aqui está um resumo: receitas R$ 28.140 · despesas R$ 16.420 · saldo R$ 11.720. Quer detalhar por categoria?" };
}

/* ============================================================
   KPIs / Saúde Financeira
   ============================================================ */
export function KPIs() {
  const score = 84;
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Score */}
        <div className="lg:col-span-1 bg-[#0E1B2C] text-white rounded-[20px] p-7 relative overflow-hidden">
          <div className="absolute inset-0 opacity-40"
               style={{ background: "radial-gradient(circle at 70% 30%, rgba(16,185,129,0.4) 0%, transparent 60%)" }}/>
          <div className="relative">
            <div className="text-xs uppercase tracking-wider text-white/60">Score de saúde financeira</div>
            <div className="mt-6 flex items-end gap-2">
              <span className="font-display text-7xl">{score}</span>
              <span className="font-display text-2xl text-white/40 mb-2">/100</span>
            </div>
            <div className="mt-2 inline-flex items-center gap-1 px-3 py-1 rounded-full bg-[#14B88A]/20 text-[#14B88A] text-xs font-semibold">
              <Heart size={12}/> Saudável
            </div>
            <div className="mt-6 h-2 bg-white/10 rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-[#14B88A] to-[#38BDF8] rounded-full" style={{ width: `${score}%` }}/>
            </div>
            <p className="mt-6 text-sm text-white/80 leading-relaxed">
              Sua empresa está saudável, mas com <span className="text-[#14B88A] font-semibold">aumento nos custos fixos</span>. Aja antes que a margem caia mais 5 pontos.
            </p>
          </div>
        </div>

        {/* KPI grid */}
        <div className="lg:col-span-2 grid grid-cols-2 gap-4">
          {[
            { l: "Margem estimada", v: "41%", t: "↑ 3pp", c: "text-[#14B88A]" },
            { l: "Custo fixo", v: "R$ 6.892", t: "42% receita", c: "text-[#F59E0B]" },
            { l: "Custo variável", v: "R$ 4.290", t: "26% receita", c: "text-[#0E1B2C]" },
            { l: "Ponto de equilíbrio", v: "R$ 11.182", t: "faturar para zerar", c: "text-[#0E1B2C]" },
            { l: "Risco caixa negativo", v: "Baixo", t: "12 dias horizon", c: "text-[#14B88A]" },
            { l: "Despesas fora do padrão", v: "3", t: "categorias", c: "text-[#DC2657]" },
          ].map((k) => (
            <div key={k.l} className="bg-white rounded-[20px] border border-border p-5">
              <div className="text-xs text-[#6B7385]">{k.l}</div>
              <div className={`font-display text-2xl mt-2 ${k.c}`}>{k.v}</div>
              <div className="text-xs text-[#6B7385] mt-1">{k.t}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Insight cards */}
      <div className="grid sm:grid-cols-3 gap-4">
        {[
          "Sua empresa está saudável, mas com aumento nos custos fixos.",
          "Você precisa faturar R$ 8.700 até o fim do mês para fechar no zero.",
          "Seus custos fixos representam 42% do faturamento.",
        ].map((t, i) => (
          <div key={i} className="bg-white rounded-[20px] border border-border p-5 flex gap-3">
            <div className="w-10 h-10 rounded-[14px] bg-[#E8F4EF] text-[#14B88A] flex items-center justify-center shrink-0">
              <Sparkles size={18}/>
            </div>
            <div className="text-sm text-[#0E1B2C] leading-relaxed">{t}</div>
          </div>
        ))}
      </div>

      {/* Comparativo */}
      <ChartCard title="Comparativo mês atual × mês anterior">
        <ResponsiveContainer width="100%" height={280}>
          <LineChart data={mockCompare}>
            <CartesianGrid strokeDasharray="3 3" stroke="#EEF1F6" vertical={false}/>
            <XAxis dataKey="d" tick={{ fontSize: 11, fill: "#6B7385" }} axisLine={false} tickLine={false}/>
            <YAxis tick={{ fontSize: 11, fill: "#6B7385" }} axisLine={false} tickLine={false}/>
            <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #EEF1F6" }}/>
            <Line type="monotone" dataKey="atual" stroke="#14B88A" strokeWidth={2.6} dot={false}/>
            <Line type="monotone" dataKey="anterior" stroke="#0E1B2C" strokeWidth={2.2} strokeDasharray="4 4" dot={false}/>
          </LineChart>
        </ResponsiveContainer>
      </ChartCard>
    </div>
  );
}

/* ============================================================
   SETTINGS
   ============================================================ */
export function SettingsScreen() {
  const [tab, setTab] = useState("Empresa");
  const tabs = ["Empresa","Usuários","Categorias","Canais","Plano","Segurança / LGPD","Exportação"];
  return (
    <div className="grid grid-cols-1 lg:grid-cols-[220px_1fr] gap-6">
      <aside className="space-y-1">
        {tabs.map((t) => (
          <button key={t} onClick={() => setTab(t)}
            className={`w-full text-left px-4 h-10 rounded-[14px] text-sm transition ${
              tab === t ? "bg-[#0E1B2C] text-white" : "text-[#6B7385] hover:bg-white"
            }`}>
            {t}
          </button>
        ))}
      </aside>

      <div className="bg-white rounded-[20px] border border-border p-7 space-y-6">
        {tab === "Empresa" && (
          <>
            <SettingHeader title="Dados da empresa" sub="Informações usadas em relatórios e exportações."/>
            <div className="grid sm:grid-cols-2 gap-4">
              <Field label="Razão social" v="Estúdio Lume MEI"/>
              <Field label="CNPJ" v="42.318.901/0001-22"/>
              <Field label="Endereço" v="Rua Augusta, 1234 · SP" full/>
              <Field label="Regime tributário" v="MEI"/>
              <Field label="Atividade principal" v="Design gráfico"/>
            </div>
          </>
        )}
        {tab === "Usuários" && (
          <>
            <SettingHeader title="Usuários e permissões" sub="Quem pode acessar seu Aionis." action="Convidar"/>
            <div className="space-y-2">
              {[
                { n: "Camila Andrade", e: "camila@estudiolume.com.br", r: "Admin" },
                { n: "Contador · Bruno", e: "bruno@contabilfocal.com.br", r: "Contador" },
                { n: "Operacional · Lia", e: "lia@estudiolume.com.br", r: "Visualizador" },
              ].map((u) => (
                <div key={u.e} className="flex items-center gap-3 p-3 rounded-[14px] border border-border">
                  <div className="w-9 h-9 rounded-full bg-[#0E1B2C] text-white flex items-center justify-center text-xs font-semibold">{u.n.split(" ").map(x=>x[0]).join("")}</div>
                  <div className="flex-1">
                    <div className="font-semibold text-sm">{u.n}</div>
                    <div className="text-xs text-[#6B7385] font-mono">{u.e}</div>
                  </div>
                  <span className="text-xs px-2 py-1 rounded-md bg-[#E8F4EF] text-[#14B88A]">{u.r}</span>
                </div>
              ))}
            </div>
          </>
        )}
        {tab === "Categorias" && (
          <>
            <SettingHeader title="Categorias financeiras" sub="Use para classificar receitas e despesas." action="Nova"/>
            <div className="flex flex-wrap gap-2">
              {["Receita serviços","Receita produtos","Aluguel","Energia","Internet","Combustível","Marketing","Impostos","Fornecedores","Salários","Software","Alimentação"].map((c) => (
                <span key={c} className="px-3 py-1.5 rounded-full bg-[#F5F4EF] text-xs flex items-center gap-1.5">
                  {c} <button className="text-[#6B7385] hover:text-[#DC2657]">×</button>
                </span>
              ))}
            </div>
          </>
        )}
        {tab === "Canais" && (
          <>
            <SettingHeader title="Canais conectados" sub="WhatsApp, e-mail e portal."/>
            <div className="space-y-3">
              {[
                { i: MessageCircle, t: "WhatsApp", d: "+55 (11) 98123-4567", on: true },
                { i: Mail, t: "E-mail de notas", d: "lume@notas.aionis.com.br", on: true },
                { i: Globe, t: "Portal de upload", d: "app.aionis.com.br/upload", on: true },
                { i: Smartphone, t: "App mobile", d: "Disponível em breve", on: false },
              ].map((c) => (
                <div key={c.t} className="flex items-center gap-4 p-4 rounded-[14px] border border-border">
                  <div className="w-10 h-10 rounded-lg bg-[#E8F4EF] text-[#14B88A] flex items-center justify-center"><c.i size={18}/></div>
                  <div className="flex-1">
                    <div className="font-semibold">{c.t}</div>
                    <div className="text-xs text-[#6B7385] font-mono">{c.d}</div>
                  </div>
                  <div className={`w-11 h-6 rounded-full p-0.5 transition ${c.on ? "bg-[#14B88A]" : "bg-[#E5E7EB]"}`}>
                    <div className={`w-5 h-5 rounded-full bg-white shadow transition ${c.on ? "translate-x-5" : ""}`}/>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
        {tab === "Plano" && (
          <>
            <SettingHeader title="Plano contratado" sub="Aionis MEI · renovação em 21/06/2026."/>
            <div className="bg-[#0E1B2C] text-white rounded-[20px] p-6 flex items-center justify-between">
              <div>
                <div className="text-xs text-white/60 uppercase tracking-wider">Plano atual</div>
                <div className="font-display text-3xl">Aionis MEI</div>
                <div className="text-sm text-white/70 mt-1">R$ 97/mês · 500 documentos</div>
              </div>
              <button className="bg-[#14B88A] hover:bg-[#0ea273] h-11 px-5 rounded-[14px]">Fazer upgrade</button>
            </div>
            <div className="grid sm:grid-cols-3 gap-4">
              {[
                { l: "Documentos", v: "312 / 500" },
                { l: "Usuários", v: "3 / 5" },
                { l: "Armazenamento", v: "2,4 / 10 GB" },
              ].map((x) => (
                <div key={x.l} className="bg-[#F5F4EF] rounded-[14px] p-4">
                  <div className="text-xs text-[#6B7385]">{x.l}</div>
                  <div className="font-display text-lg mt-1">{x.v}</div>
                </div>
              ))}
            </div>
          </>
        )}
        {tab === "Segurança / LGPD" && (
          <>
            <SettingHeader title="Segurança e LGPD" sub="Seus dados são criptografados e armazenados em conformidade."/>
            <div className="grid sm:grid-cols-2 gap-4">
              <SecCard icon={Shield} t="Criptografia em repouso" d="AES-256 em todos os documentos."/>
              <SecCard icon={Lock} t="Autenticação 2FA" d="Ativada via app autenticador."/>
              <SecCard icon={FileText} t="Termo LGPD" d="Aceito em 02/03/2026."/>
              <SecCard icon={Users} t="Política de retenção" d="Documentos guardados por 5 anos."/>
            </div>
          </>
        )}
        {tab === "Exportação" && (
          <>
            <SettingHeader title="Exportação de dados" sub="Baixe seus dados para contador ou backup pessoal."/>
            <div className="grid sm:grid-cols-3 gap-4">
              {[
                { t: "Lançamentos (CSV)", d: "Receitas e despesas detalhados." },
                { t: "Pacote contador", d: "Formato esperado pelo escritório." },
                { t: "Documentos (ZIP)", d: "Todos os PDFs e imagens." },
              ].map((x) => (
                <button key={x.t} className="text-left p-5 rounded-[14px] border border-border hover:border-[#14B88A]/40 hover:bg-[#E8F4EF]/30 transition">
                  <Download size={20} className="text-[#14B88A] mb-3"/>
                  <div className="font-display font-semibold">{x.t}</div>
                  <div className="text-xs text-[#6B7385] mt-1">{x.d}</div>
                </button>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
function SettingHeader({ title, sub, action }: { title: string; sub: string; action?: string }) {
  return (
    <div className="flex items-center justify-between pb-4 border-b border-border">
      <div>
        <h2 className="font-display">{title}</h2>
        <p className="text-sm text-[#6B7385] mt-0.5">{sub}</p>
      </div>
      {action && <button className="h-10 px-4 rounded-[14px] bg-[#14B88A] hover:bg-[#0ea273] text-white text-sm flex items-center gap-1.5"><Plus size={14}/> {action}</button>}
    </div>
  );
}
function SecCard({ icon: Icon, t, d }: any) {
  return (
    <div className="flex items-start gap-3 p-4 rounded-[14px] border border-border">
      <div className="w-10 h-10 rounded-lg bg-[#E8F4EF] text-[#14B88A] flex items-center justify-center shrink-0"><Icon size={18}/></div>
      <div>
        <div className="font-semibold text-sm">{t}</div>
        <div className="text-xs text-[#6B7385] mt-0.5">{d}</div>
      </div>
    </div>
  );
}

/* ============================================================
   Mock data
   ============================================================ */
const mockFlow = [
  { d: "1", v: 12 }, { d: "5", v: 18 }, { d: "10", v: 14 }, { d: "15", v: 22 },
  { d: "20", v: 28 }, { d: "25", v: 26 }, { d: "30", v: 34 },
];
const mockFlow30 = Array.from({ length: 30 }, (_, i) => ({
  d: String(i + 1).padStart(2, "0"),
  rec: 800 + Math.round(Math.sin(i / 3) * 400 + Math.random() * 300 + i * 12),
  desp: 500 + Math.round(Math.cos(i / 4) * 300 + Math.random() * 220 + i * 6),
}));
const mockCats = [
  { n: "Aluguel", v: 1500 },
  { n: "Combustível", v: 1840 },
  { n: "Internet", v: 489 },
  { n: "Software", v: 287 },
  { n: "Outros", v: 642 },
];
const mockRD = [
  { m: "Jan", rec: 18, desp: 12 }, { m: "Fev", rec: 22, desp: 14 },
  { m: "Mar", rec: 25, desp: 17 }, { m: "Abr", rec: 24, desp: 18 },
  { m: "Mai", rec: 28, desp: 16 }, { m: "Jun", rec: 0, desp: 0 },
];
const mockCompare = Array.from({ length: 30 }, (_, i) => ({
  d: String(i + 1).padStart(2, "0"),
  atual: 800 + Math.round(Math.sin(i / 3) * 400 + i * 18),
  anterior: 700 + Math.round(Math.cos(i / 4) * 350 + i * 12),
}));
