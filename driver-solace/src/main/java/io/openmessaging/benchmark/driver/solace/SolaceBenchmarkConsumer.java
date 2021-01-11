package io.openmessaging.benchmark.driver.solace;

import java.util.concurrent.TimeUnit;

import com.solacesystems.jcsmp.BytesMessage;
import com.solacesystems.jcsmp.BytesXMLMessage;
import com.solacesystems.jcsmp.InvalidPropertiesException;
import com.solacesystems.jcsmp.JCSMPException;
import com.solacesystems.jcsmp.JCSMPFactory;
import com.solacesystems.jcsmp.JCSMPProperties;
import com.solacesystems.jcsmp.JCSMPSession;
import com.solacesystems.jcsmp.JCSMPStreamingPublishEventHandler;
import com.solacesystems.jcsmp.Topic;
import com.solacesystems.jcsmp.XMLMessageConsumer;
import com.solacesystems.jcsmp.XMLMessageListener;
import com.solacesystems.jcsmp.XMLMessageProducer;

import io.openmessaging.benchmark.driver.BenchmarkConsumer;
import io.openmessaging.benchmark.driver.ConsumerCallback;

public class SolaceBenchmarkConsumer implements BenchmarkConsumer {

	private JCSMPSession session;
	private XMLMessageConsumer consumer;
	private Topic topic;

	public SolaceBenchmarkConsumer(JCSMPProperties properties, String topic, ConsumerCallback callback) {

		try {
			session = JCSMPFactory.onlyInstance().createSession(properties);
			session.connect();

			consumer = session.getMessageConsumer(new XMLMessageListener() {

				@Override
				public void onReceive(BytesXMLMessage message) {
					callback.messageReceived(message.getBytes(),
							TimeUnit.MILLISECONDS.toNanos(message.getReceiveTimestamp()));
				}

				@Override
				public void onException(JCSMPException exception) {
					// TODO Auto-generated method stub

				}
			});

			this.topic = JCSMPFactory.onlyInstance().createTopic(topic);

		} catch (InvalidPropertiesException ex) {
			// TODO: Exception Handling
		} catch (JCSMPException ex) {
			// TODO : Exception Handling
		}
	}

	@Override
	public void close() throws Exception {
		consumer.close();
		session.closeSession();
	}

}
