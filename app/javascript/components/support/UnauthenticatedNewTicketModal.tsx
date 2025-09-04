import React from "react";

import FileUtils from "$app/utils/file";

import { Button } from "$app/components/Button";
import { FileRowContent } from "$app/components/FileRowContent";
import { Icon } from "$app/components/Icons";
import { Modal } from "$app/components/Modal";
import { showAlert } from "$app/components/server-components/Alert";
import { useRecaptcha, RecaptchaCancelledError } from "$app/components/useRecaptcha";

export function UnauthenticatedNewTicketModal({
  open,
  onClose,
  onCreated,
  recaptchaSiteKey,
}: {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
  recaptchaSiteKey: string;
}) {
  const formRef = React.useRef<HTMLFormElement | null>(null);
  const { container: recaptchaContainer, execute: executeRecaptcha } = useRecaptcha({
    siteKey: recaptchaSiteKey || null,
  });

  const [email, setEmail] = React.useState("");
  const [subject, setSubject] = React.useState("");
  const [message, setMessage] = React.useState("");
  const [attachments, setAttachments] = React.useState<File[]>([]);
  const [isSubmitting, setIsSubmitting] = React.useState(false);

  const fileInputRef = React.useRef<HTMLInputElement | null>(null);

  const isFormValid = email.trim() && subject.trim() && message.trim();

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!isFormValid) return;

    setIsSubmitting(true);
    try {
      const recaptchaResponse = recaptchaSiteKey ? await executeRecaptcha() : null;

      const response = await fetch("/support/create_unauthenticated_ticket", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || "",
        },
        body: JSON.stringify({
          email: email.trim(),
          subject: subject.trim(),
          message: message.trim(),
          "g-recaptcha-response": recaptchaResponse,
        }),
      });

      if (response.ok) {
        showAlert("Your support ticket has been created successfully! We'll get back to you via email.", "success");
        onCreated();
        setEmail("");
        setSubject("");
        setMessage("");
        setAttachments([]);
      } else {
        let errorMessage = "Failed to create support ticket";
        const data: unknown = await response.json();
        if (typeof data === "object" && data !== null && "error" in data && typeof data.error === "string") {
          errorMessage = data.error;
        }
        showAlert(errorMessage, "error");
      }
    } catch (error: unknown) {
      if (error instanceof RecaptchaCancelledError) {
        setIsSubmitting(false);
        return;
      }
      const errorMessage = error instanceof Error ? error.message : "Unknown error";
      showAlert(`Failed to create support ticket. Please try again. ${errorMessage}`, "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="How can we help you today?"
      footer={
        <>
          <Button onClick={() => fileInputRef.current?.click()} disabled={isSubmitting}>
            <Icon name="paperclip" /> Attach files
          </Button>
          <Button
            color="accent"
            onClick={() => {
              formRef.current?.requestSubmit();
            }}
            disabled={isSubmitting || !isFormValid}
          >
            {isSubmitting ? "Sending..." : "Send message"}
          </Button>
        </>
      }
    >
      <form
        ref={formRef}
        className="space-y-4 md:w-[700px]"
        onSubmit={(e) => {
          void handleSubmit(e);
        }}
      >
        <div>
          <label className="sr-only">Email address</label>
          <input
            type="email"
            value={email}
            placeholder="Your email address"
            onChange={(e) => setEmail(e.target.value)}
            required
            className="w-full"
          />
        </div>
        <div>
          <label className="sr-only">Subject</label>
          <input
            value={subject}
            placeholder="Subject"
            onChange={(e) => setSubject(e.target.value)}
            required
            className="w-full"
          />
        </div>
        <div>
          <label className="sr-only">Message</label>
          <textarea
            rows={6}
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Tell us about your issue or question..."
            required
            className="w-full"
          />
        </div>
        <input
          ref={fileInputRef}
          type="file"
          multiple
          style={{ display: "none" }}
          onChange={(e) => {
            const files = Array.from(e.target.files ?? []);
            if (files.length === 0) return;
            setAttachments((prev) => [...prev, ...files]);
            e.currentTarget.value = "";
          }}
        />
        {attachments.length > 0 ? (
          <div role="list" className="rows">
            {attachments.map((file, i) => (
              <div key={i} role="listitem" className="row">
                <FileRowContent
                  name={FileUtils.getFileNameWithoutExtension(file.name)}
                  extension={FileUtils.getFileExtension(file.name).toUpperCase()}
                  externalLinkUrl={null}
                  details={
                    <>
                      <li>{FileUtils.getFileExtension(file.name).toUpperCase()}</li>
                      <li>{FileUtils.getFullFileSizeString(file.size)}</li>
                    </>
                  }
                />
                <Button
                  onClick={() => {
                    setAttachments((prev) => prev.filter((_, index) => index !== i));
                  }}
                  disabled={isSubmitting}
                >
                  <Icon name="x" />
                  <span className="sr-only">Remove {file.name}</span>
                </Button>
              </div>
            ))}
          </div>
        ) : null}
        {recaptchaContainer}
      </form>
    </Modal>
  );
}
