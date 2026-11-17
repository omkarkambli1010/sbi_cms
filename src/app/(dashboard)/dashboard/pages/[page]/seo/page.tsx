import { notFound } from "next/navigation";

import SeoScreen from "@/components/dashboard/SeoScreen";
import { resolvePage } from "@/server/cms/pages";

interface Params {
  params: Promise<{ page: string }>;
}

export async function generateMetadata({ params }: Params) {
  const page = resolvePage((await params).page);
  return { title: page ? `${page.label} — SEO` : "SEO" };
}

export default async function PageSeo({ params }: Params) {
  const slug = (await params).page;
  const page = resolvePage(slug);
  if (!page) notFound();
  return <SeoScreen slug={slug} pageLabel={page.label} />;
}
