package io.openmessaging.benchmark.driver.solace;

import java.util.Optional;
import java.util.concurrent.CompletableFuture;

import com.solacesystems.jcsmp.BytesMessage;
import com.solacesystems.jcsmp.InvalidPropertiesException;
import com.solacesystems.jcsmp.JCSMPException;
import com.solacesystems.jcsmp.JCSMPFactory;
import com.solacesystems.jcsmp.JCSMPProperties;
import com.solacesystems.jcsmp.JCSMPSession;
import com.solacesystems.jcsmp.JCSMPStreamingPublishEventHandler;
import com.solacesystems.jcsmp.Topic;
import com.solacesystems.jcsmp.TopicEndpoint;
import com.solacesystems.jcsmp.XMLMessageProducer;

import io.openmessaging.benchmark.driver.BenchmarkProducer;

public class SolaceBenchmarkProducer implements BenchmarkProducer {

	private JCSMPSession session;
	private XMLMessageProducer producer;
	private Topic topic;
	private BytesMessage message;

	public SolaceBenchmarkProducer(JCSMPProperties properties, String topic) {

		try {
			session = JCSMPFactory.onlyInstance().createSession(properties);
			session.connect();

			producer = session.getMessageProducer(new SolaceDriverStreamingPublishEventHandler());
		} catch (InvalidPropertiesException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (JCSMPException e) {
			e.printStackTrace();
		}

		this.topic = JCSMPFactory.onlyInstance().createTopic(topic);
		message = JCSMPFactory.onlyInstance().createMessage(BytesMessage.class);
	}

	@Override
	public void close() throws Exception {
		producer.close();
		session.closeSession();
	}

	@Override
	public CompletableFuture<Void> sendAsync(Optional<String> key, byte[] payload) {

		CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
			message.setData(payload);

			try {
				producer.send(message, topic);
			} catch (JCSMPException ex) {
				// TODO: Exception
			}
		});

		return future;
	}
}

/*
 * Handler for events related to the producer
 */
class SolaceDriverStreamingPublishEventHandler implements JCSMPStreamingPublishEventHandler {

	@Override
	public void handleError(String arg0, JCSMPException arg1, long arg2) {
		// TODO Auto-generated method stub

	}

	@Override
	public void responseReceived(String arg0) {
		// TODO Auto-generated method stub

	}

}
