import React, { useEffect } from "react";

import { Button } from "$app/components/Button";
import { SupportHeader } from "$app/components/server-components/support/Header";
import { useGlobalEventListener } from "$app/components/useGlobalEventListener";
import { useOriginalLocation } from "$app/components/useOriginalLocation";

import { UnauthenticatedNewTicketModal } from "./UnauthenticatedNewTicketModal";

import placeholderImage from "$assets/images/placeholders/support.png";

type Props = {
  recaptchaSiteKey: string;
};

export default function UnauthenticatedSupportPortal({ recaptchaSiteKey }: Props) {
  const { searchParams } = new URL(useOriginalLocation());
  const [isNewTicketOpen, setIsNewTicketOpen] = React.useState(!!searchParams.get("new_ticket"));

  useEffect(() => {
    const url = new URL(location.href);
    if (!isNewTicketOpen && url.searchParams.get("new_ticket")) {
      url.searchParams.delete("new_ticket");
      history.replaceState(null, "", url.toString());
    }
  }, [isNewTicketOpen]);

  useGlobalEventListener("popstate", () => {
    const params = new URL(location.href).searchParams;
    setIsNewTicketOpen(!!params.get("new_ticket"));
  });

  return (
    <>
      <main>
        <header>
          <SupportHeader onOpenNewTicket={() => setIsNewTicketOpen(true)} hasHelperSession={false} />
        </header>
        <section>
          <div className="placeholder">
            <figure>
              <img src={placeholderImage} alt="Support" />
            </figure>
            <h2>Need a hand? We're here for you.</h2>
            <p>
              Got a question about selling, payouts, or your products? Send us a message and we'll get back to you as
              soon as possible.
            </p>
            <Button color="accent" onClick={() => setIsNewTicketOpen(true)}>
              Contact support
            </Button>
            <div className="text-gray-600 mt-4 text-sm">
              <p>
                Have a Gumroad account?{" "}
                <a href="/login" className="text-blue-600 hover:underline">
                  Sign in
                </a>{" "}
                to access your support tickets.
              </p>
            </div>
          </div>
        </section>
      </main>
      <UnauthenticatedNewTicketModal
        open={isNewTicketOpen}
        onClose={() => setIsNewTicketOpen(false)}
        onCreated={() => {
          setIsNewTicketOpen(false);
        }}
        recaptchaSiteKey={recaptchaSiteKey}
      />
    </>
  );
}
