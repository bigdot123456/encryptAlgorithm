/*
 �����ܳ���ʵ�ֶ��ļ��Ľ���
*/
#include "md5.h"
#include "AES.h"


int runDeCry(char* md5key,unsigned char * Imem,unsigned char * Omem,unsigned long mem_length); ////����
unsigned long GetFileLen1(const char* szFilePath); //�õ��ļ��ĳ���

extern "C" 
int jiemi(char* md5key,char* filepath) 
{
	int deviceCount = 0;
	CUDA_SAFE_CALL(cudaGetDeviceCount(&deviceCount));
	
	//û��֧��CUDA���豸
	if(deviceCount==0)
	{
		printf("�����豸��֧��CUDA��\n");
		return -1;
	}

	//���������汾
    int dev;
	int driverVersion = 0;     
    for (dev = 0; dev < deviceCount; ++dev) 
	{
        cudaDeviceProp deviceProp;
        cudaGetDeviceProperties(&deviceProp, dev);
		if(CUDART_VERSION >= 2020)
		{
			cudaDriverGetVersion(&driverVersion);
			//printf("CUDA Driver Version: %d.%d\n", driverVersion/1000, driverVersion%100);
			if(driverVersion/1000 < 3 || driverVersion/1000 == 3 && driverVersion%100 < 2)
			{
				printf("�����Կ������汾̫�ͣ�������Կ�������\n");
				return -2;
			}
		}
		else
			printf("�����Կ������汾̫�ͣ�������Կ�������\n");
	}

	//��������ʱ��
	clock_t start, finish, cost;
	double totaltime;

	FILE *fp;							//���ļ��ж�������
	if((fp=fopen(filepath,"rb"))==NULL)
	{
		printf("�޷�������ѡ����ļ�\n");
		exit(0);
	}
	unsigned long input_length = GetFileLen1(filepath);	        //���볤��
	unsigned long mem_length = (input_length + 1024 * 16 - 1) / 4;	//�洢������,��16k����
	unsigned char *Aes;									            //�ڴ��е�����
	Aes = (unsigned char*) malloc(sizeof(unsigned int) * mem_length);	//���ڴ���Ϊ���ķ���ռ�
	unsigned char *OAes;									               //�ڴ��е�����
	OAes = (unsigned char*) malloc(sizeof(unsigned int) * mem_length);  //���ڴ���Ϊ���ķ���ռ�
	
	fread(Aes, sizeof(unsigned char), input_length, fp);
	for(unsigned int i = input_length; i < 4 * mem_length; i ++)
	{
		Aes[i] = 0;
	}
	fclose(fp);

	printf("\n");
	printf("���ڽ���, AES128, EBC mode ...\n");

	start=clock();
    runDeCry(md5key,Aes,OAes,mem_length);
	finish=clock();

	char filename[260];
	strcpy(filename,filepath);
	strcat(filename,".changeme");
//	int size;
	//filename[strlen(filename) - 4] = '\0';			//�����ļ���Ϊ�����ļ�ȥ����׺.bfe
	FILE* fp_w = fopen(filename,"wb");
//	printf("%s",filename);
	//д������ļ�
	fwrite(OAes, sizeof(unsigned char), (input_length + 15) / 16 * 16, fp_w);
//	printf("%d\n",size);

	fclose(fp_w);
		
	// �ͷſռ�
	free(Aes);
	free(OAes);

	totaltime=(double)(finish-start)/CLOCKS_PER_SEC;
    printf("��������ʱ��Ϊ%f��! �������ݴ����ٶ�%f MBytes/s!\n",totaltime, input_length / totaltime / 1024 / 1024);

	return 0;
}

//����
int runDeCry(char* md5key,unsigned char * Imem,unsigned char * Omem,unsigned long mem_length) 
{
	unsigned char *IAes;
	unsigned char *OAes;
	int nouse;
	unsigned char mykey[16]; //��չ���� 
	int round;
	//MD5��չ�û�����
	MD5 md5;
/*	if(argc < 2)		//���û�������ļ��������˳���
	{
		printf("��ѡ��Ҫ���ܵ��ļ��������������룡\n");
		return -1;
	}
*/	
    md5.Data((unsigned char *)md5key,strlen(md5key),mykey);

	//����Ҫ���ܵ��ļ�
//	for(int k = 2; k < argc; ++k)
//	{

		//����û����������Ƿ���ȷ
/*		unsigned char pswd[16];
		fread(pswd, sizeof(unsigned char), 16, fp);
		if(memcmp(pswd,mykey,sizeof(pswd)))
		{
			printf("�û�����У��ʧ�ܣ�\n");
			return 2;
		}
*/
	unsigned int *roundkey;									            //�ڴ��е�����
	roundkey = (unsigned int*) malloc(sizeof(unsigned int) * 44);	    //���ڴ���Ϊ���ķ���ռ�
	if(mem_length < PIECE_SIZE)
	{
		unsigned int* d_roundkey;
		
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_roundkey, sizeof(unsigned int) * 44 ));
		
		AesSetKeyDecode(roundkey, mykey, 16);//�����������Կ
		
		CUDA_SAFE_CALL( cudaMemcpy( d_roundkey, roundkey, sizeof(unsigned int) * 44 ,cudaMemcpyHostToDevice) );	//������Կ�������Դ���	
		//��ʼ��CUDA���л���
	//	cudaSetDevice(0);	

		//Ϊ���ķ����Դ�
		unsigned int* d_Aes;		
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_Aes, sizeof(unsigned int) * (mem_length )));

		//Ϊ��������Դ�
		unsigned int* d_OAes;			
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_OAes, sizeof(unsigned int) * mem_length ));

	
		//�����Ŀ������Դ���
		CUDA_SAFE_CALL( cudaMemcpy( d_Aes, Imem, sizeof(unsigned int) * mem_length, cudaMemcpyHostToDevice) );

		// ����ִ�в���
		dim3  grid( (mem_length ) / BLOCK_SIZE / LOOP_IN_BLOCK , 1, 1);		//����grid, grid��СΪ ���ĳ���/ һ��BLOCK�д����32bit integer�� / BLOCK��ѭ������												
		dim3  threads( BLOCK_SIZE, 1, 1);

		/*��ʼ����*/							
		AES128_EBC_decry_kernel<<< grid, threads>>>(d_Aes, d_OAes, d_roundkey);

		CUT_CHECK_ERROR("Kernel execution failed\n");	//����Ƿ���ȷִ��

		CUDA_SAFE_CALL( cudaMemcpy( Omem, d_OAes, sizeof(unsigned int) * mem_length,cudaMemcpyDeviceToHost) );//��������Դ濽�����ڴ�
			
		//��������ļ����ļ���
		free(roundkey);

		CUDA_SAFE_CALL(cudaFree(d_Aes));
		CUDA_SAFE_CALL(cudaFree(d_OAes));
		CUDA_SAFE_CALL(cudaFree(d_roundkey));
	}
	else
	{
		printf("->\n");
		IAes = Imem;
		OAes = Omem;
		unsigned long mem_remainder;
		int time;
		round = mem_length/PIECE_SIZE;
		mem_remainder = mem_length%PIECE_SIZE;


		unsigned int* d_roundkey;
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_roundkey, sizeof(unsigned int) * 44 ));
		
		AesSetKeyDecode(roundkey, mykey, 16);//�����������Կ
		
		CUDA_SAFE_CALL( cudaMemcpy( d_roundkey, roundkey, sizeof(unsigned int) * 44 ,cudaMemcpyHostToDevice) );	//������Կ�������Դ���	
		//��ʼ��CUDA���л���
	//	cudaSetDevice(0);	
  		printf("���ڽ���...\n");
		unsigned int* d_Aes;		

		unsigned int* d_OAes;			

		//Ϊ���ķ����Դ�
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_Aes, sizeof(unsigned int) * PIECE_SIZE));

		//Ϊ��������Դ�
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_OAes, sizeof(unsigned int) * PIECE_SIZE ));

			
		for(time = 0;time < round;time++)
		{
 //			printf("%d\n",IAes);
//			printf("%d\n",OAes);


			//�����Ŀ������Դ���
			CUDA_SAFE_CALL( cudaMemcpy( d_Aes, IAes, sizeof(unsigned int) * PIECE_SIZE, cudaMemcpyHostToDevice) );

			// ����ִ�в���
			dim3  grid( PIECE_SIZE / BLOCK_SIZE / LOOP_IN_BLOCK , 1, 1);		//����grid, grid��СΪ ���ĳ���/ һ��BLOCK�д����32bit integer�� / BLOCK��ѭ������												
			dim3  threads( BLOCK_SIZE, 1, 1);

			/*��ʼ����*/

			AES128_EBC_decry_kernel<<< grid, threads>>>(d_Aes, d_OAes, d_roundkey);

			CUT_CHECK_ERROR("Kernel execution failed\n");	//����Ƿ���ȷִ��

			CUDA_SAFE_CALL( cudaMemcpy( OAes, d_OAes, sizeof(unsigned int) * PIECE_SIZE,cudaMemcpyDeviceToHost) );//��������Դ濽�����ڴ�
			IAes = Imem + (time + 1)*PIECE_SIZE*4;
			OAes = Omem + (time + 1)*PIECE_SIZE*4;


		}
		//��������ļ����ļ���

		CUDA_SAFE_CALL(cudaFree(d_Aes));
		CUDA_SAFE_CALL(cudaFree(d_OAes));

		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_Aes, sizeof(unsigned int) * (mem_remainder)));
		CUDA_SAFE_CALL( cudaMalloc( (void**) &d_OAes, sizeof(unsigned int) * (mem_remainder)));
		CUDA_SAFE_CALL( cudaMemcpy( d_Aes, IAes, sizeof(unsigned int) * (mem_remainder), cudaMemcpyHostToDevice) );

		// �������в���
		dim3  grid( (mem_remainder) / BLOCK_SIZE / LOOP_IN_BLOCK , 1, 1);		//����grid, grid��СΪ ���ĳ���/ һ��BLOCK�д����32bit integer�� / BLOCK��ѭ������												
		dim3  threads( BLOCK_SIZE, 1, 1);

		AES128_EBC_decry_kernel<<< grid, threads>>>(d_Aes, d_OAes, d_roundkey);

		CUT_CHECK_ERROR("CUDA�ں�ִ��ʧ�ܣ�\n");	//����Ƿ���ȷִ��


		CUDA_SAFE_CALL( cudaMemcpy( OAes, d_OAes, sizeof(unsigned int) * mem_remainder,cudaMemcpyDeviceToHost) );//��������Դ濽�����ڴ�	

		free(roundkey);
		CUDA_SAFE_CALL(cudaFree(d_Aes));
		CUDA_SAFE_CALL(cudaFree(d_OAes));
		CUDA_SAFE_CALL(cudaFree(d_roundkey));
	}

//	}	
	return 0;
}
	
unsigned long GetFileLen1(const char* szFilePath)
{
	FILE* pFile = fopen(szFilePath, "rb");
	if (pFile == NULL)
		return -1;

	fseek(pFile, 0, SEEK_END);
	long nFileLen = ftell(pFile);
	fclose(pFile);

	return nFileLen;
}
