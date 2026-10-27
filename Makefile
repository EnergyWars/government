FEEDBACK_SERVER_DIR := feedback-server

.PHONY: feedback-server

feedback-server:
	cd $(FEEDBACK_SERVER_DIR) && exec python3 -m feedback_server
