import { notFound } from "next/navigation";

import SectionScreen from "@/components/dashboard/SectionScreen";
import { resolveSection, SECTION_ORDER } from "@/server/cms/registry";

interface Params {
  params: Promise<{ section: string }>;
}

/** One route serves all fifteen folds; the registry says what each contains. */
export function generateStaticParams() {
  return SECTION_ORDER.map((section) => ({ section }));
}

export async function generateMetadata({ params }: Params) {
  const def = resolveSection((await params).section);
  return { title: def?.label ?? "Section" };
}

export default async function SectionPage({ params }: Params) {
  const def = resolveSection((await params).section);

  if (!def) notFound();

  /* Passed whole rather than re-derived in the client: the screen and the API
     then read the same description of the fold, which is the point of the
     registry. */
  return <SectionScreen def={def} />;
}
