package io.integon;

import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

import java.io.IOException;
import java.net.URISyntaxException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.Collections;
import java.util.concurrent.TimeoutException;

import com.rabbitmq.client.Channel;

public class App {
    public static void main(String[] args)
            throws IOException, TimeoutException, KeyManagementException, NoSuchAlgorithmException, URISyntaxException {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setUri("amqp://guest:guest@127.0.0.1:5672");
        Connection conn = factory.newConnection();
        System.out.println("Connection established");
        String exchangeName = "javaExchange";

        new Thread(() -> {
            try {
                Channel channel = conn.createChannel();

                channel.exchangeDeclare(exchangeName, "direct", true);
                System.out.println("Exchange declared");
                channel.queueDeclare(
                        "java-stream",
                        true, // durable
                        false, false, // not exclusive, not auto-delete
                        Collections.singletonMap("x-queue-type", "stream"));
                channel.queueBind("java-stream", exchangeName, exchangeName);

                channel.basicQos(100); // QoS must be specified
                channel.basicConsume(
                        "java-stream",
                        false,
                        Collections.singletonMap("x-stream-offset", "first"), // "first" offset specification
                        (consumerTag, message) -> {
                            System.out.println("Received message: " + new String(message.getBody(), "UTF-8"));
                            channel.basicAck(message.getEnvelope().getDeliveryTag(), false); // ack is required
                        },
                        consumerTag -> {
                        });
            } catch (IOException e) {
                e.printStackTrace();
            }
        }).start();
        Channel channel_b = conn.createChannel();

        while (true) {
            byte[] messageBodyBytes = "Hello, world!".getBytes();
            channel_b.basicPublish(exchangeName, exchangeName, null, messageBodyBytes);
            System.out.println("Sent message: " + new String(messageBodyBytes, "UTF-8"));
        }
    }
}
