import type { Metadata, Viewport } from "next";
import { WorkspaceShell } from "@/components/layout/workspace-shell";
import { siteConfig } from "@/config/site";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: `${siteConfig.name} — Business starts here`, template: `%s | ${siteConfig.name}` },
  description: siteConfig.description,
  robots: { index: false, follow: false },
};
export const viewport: Viewport = { themeColor: "#171b23", colorScheme: "light" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body suppressHydrationWarning>
        <WorkspaceShell>{children}</WorkspaceShell>
      </body>
    </html>
  );
}
