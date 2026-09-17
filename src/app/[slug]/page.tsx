import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { navigation } from "@/lib/navigation";

export function generateStaticParams() {
  return navigation.filter((item) => item.slug !== "dashboard").map((item) => ({ slug: item.slug }));
}

export default async function ModulePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  if (!navigation.some((item) => item.slug === slug)) notFound();
  return <AppShell activeSlug={slug} />;
}
