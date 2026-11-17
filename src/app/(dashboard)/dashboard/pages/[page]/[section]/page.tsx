import { notFound } from "next/navigation";

import ContentSectionScreen from "@/components/dashboard/ContentSectionScreen";
import SectionScreen from "@/components/dashboard/SectionScreen";
import { CONTENT_PAGE_ORDER, resolveContentSection, resolvePage } from "@/server/cms/pages";
import { resolveSection } from "@/server/cms/registry";

interface Params {
  params: Promise<{ page: string; section: string }>;
}

export function generateStaticParams() {
  return CONTENT_PAGE_ORDER.flatMap((page) =>
    (resolvePage(page)?.sectionOrder ?? []).map((section) => ({ page, section })),
  );
}

export async function generateMetadata({ params }: Params) {
  const { page, section } = await params;
  return {
    title:
      resolveContentSection(page, section)?.label ?? resolveSection(section)?.label ?? "Section",
  };
}

/**
 * One route for every section of every inner page. A section stored generically
 * is described by pages.ts; a home fold reused on the page (the FAQ, the app
 * promo, the sticky nudge, the research reports) is edited through its
 * registry.ts definition, with the page named so the API reads this page's
 * rows rather than the home page's.
 */
export default async function PageSectionScreen({ params }: Params) {
  const { page, section } = await params;
  const def = resolvePage(page);
  if (!def || !def.sectionOrder.includes(section)) notFound();

  const content = resolveContentSection(page, section);
  if (content) {
    return <ContentSectionScreen page={page} pageLabel={def.label} section={content} />;
  }

  const shared = resolveSection(section);
  if (!shared) notFound();
  return <SectionScreen def={shared} page={page} pageLabel={def.label} />;
}
